#!/usr/bin/env python3
"""Behavioural oracle for the WZAimRuntime external write-sustain budget.

The runtime cannot be compiled or run off-device: it links wxmem and the
kexploit transport.  This test therefore re-implements the *exact* sustain
state machine copied from WZAimRuntime.mm and asserts the properties that the
fix depends on.  It is a model, not the shipped code, so it also pins the
source text to the model constants -- if either drifts, this test fails.

Properties under test
  P1  A writer that never wins stops after exactly the frame budget and
      restores the original (no infinite spin).
  P2  A writer whose value the engine keeps is NOT torn down on the first
      rejection, which was the original defect.
  P3  Budget is refilled by every successful write, so a winning writer
      sustains indefinitely.
  P4  Sustain survives ClearGestureStateLocked (soft per-frame failures) but
      is ended by EndSustainLocked (detach / disable / revoke).
  P5  sustainWriter without memoryWriterArmed is forced off.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RUNTIME = ROOT / "lara" / "kexploit" / "wz" / "WZAimRuntime.mm"
HEADER = ROOT / "lara" / "kexploit" / "wz" / "WZAimRuntime.h"

failures = []


def check(condition, message):
    if not condition:
        failures.append(message)


# --- Model of the shipped state machine -------------------------------------
class SustainModel:
    def __init__(self, budget, sustain_writer=1, memory_writer_armed=1,
                 gesture_active=True):
        self.budget = budget
        self.sustain_writer = 1 if (sustain_writer and memory_writer_armed) else 0
        self.memory_writer_armed = memory_writer_armed
        self.remaining = 0
        self.original_captured = True   # the engine value was captured
        self.applied = 0
        self.rejected = 0
        self.restores = 0
        self.exhausted = False
        self.gesture_active = gesture_active

    def rearm(self):
        self.exhausted = False
        self.arm()

    def arm(self):
        self.remaining = self.budget if self.sustain_writer else 0

    def end(self):
        self.remaining = 0

    def clear_gesture(self):
        # Deliberately does NOT touch sustain.
        self.gesture_active = False

    def frame(self, write_succeeds, engine_kept_our_value):
        """One wzaim_runtime_consume_snapshot write-path frame."""
        if self.exhausted or (not self.gesture_active and self.remaining == 0):
            return "abstain"

        wrote = write_succeeds
        if wrote:
            self.original_captured = True
            self.arm()
            self.applied += 1
        elif self.remaining > 0 and engine_kept_our_value:
            self.applied += 1
        else:
            self.rejected += 1
            if self.remaining > 0:
                self.remaining -= 1

        if (self.sustain_writer != 0 and not wrote
                and self.remaining == 0 and self.original_captured
                and not self.exhausted):
            self.restores += 1
            self.end()
            self.exhausted = True
            return "exhausted"
        return "wrote" if wrote else "retry"


# --- P1: a losing writer is bounded ----------------------------------------
# The budget counts rejections, not retries-after-the-budget: the frame that
# decrements the last unit also observes remaining == 0 and exhausts.  So a
# fresh budget of N survives N-1 pure rejections and terminates on the Nth.
BUDGET = 600
m = SustainModel(BUDGET)
m.arm()
for i in range(BUDGET - 1):
    outcome = m.frame(write_succeeds=False, engine_kept_our_value=False)
    check(outcome == "retry", f"P1: frame {i} ended early as {outcome}")
check(m.remaining == 1, f"P1: expected 1 frame left, got {m.remaining}")
outcome = m.frame(write_succeeds=False, engine_kept_our_value=False)
check(outcome == "exhausted", f"P1: expected exhausted, got {outcome}")
check(m.remaining == 0, "P1: budget did not drain to zero")
check(m.restores == 1, "P1: original was not restored exactly once")
check(m.rejected == BUDGET, f"P1: rejected count {m.rejected} != {BUDGET}")
check(m.applied == 0, "P1: a losing writer recorded an applied write")

# Bounded means bounded: it must stay stopped afterwards.
for _ in range(10):
    check(m.frame(write_succeeds=False, engine_kept_our_value=False) == "abstain",
          "P1: writer restarted after exhausting its budget")

# --- P2: the original defect must not reappear ------------------------------
m = SustainModel(BUDGET)
m.arm()
for _ in range(5):
    outcome = m.frame(write_succeeds=False, engine_kept_our_value=False)
check(m.restores == 0, "P2: first rejection still restores/gives up")
check(outcome == "retry", "P2: writer did not keep trying after rejection")
check(m.remaining == BUDGET - 5, f"P2: budget {m.remaining} did not track rejections")

# --- P3: a winning writer sustains indefinitely -----------------------------
m = SustainModel(BUDGET)
m.arm()
for _ in range(BUDGET * 4):
    outcome = m.frame(write_succeeds=True, engine_kept_our_value=True)
check(outcome == "wrote", "P3: winning writer stopped writing")
check(m.remaining == BUDGET, "P3: budget was not refilled by success")
check(m.restores == 0, "P3: winning writer restored the original")

# --- P4: sustain outlives soft clears, dies on hard end ---------------------
m = SustainModel(BUDGET)
m.arm()
for _ in range(10):
    m.frame(write_succeeds=False, engine_kept_our_value=False)
before = m.remaining
m.clear_gesture()
check(m.remaining == before, "P4: ClearGestureStateLocked wrongly ended sustain")
check(m.frame(write_succeeds=False, engine_kept_our_value=False) == "retry",
      "P4: sustain did not survive the soft clear")
m.end()
check(m.frame(write_succeeds=False, engine_kept_our_value=False) == "abstain",
      "P4: EndSustainLocked did not stop the writer")

# A fresh gesture must be able to try again after exhaustion.
m = SustainModel(BUDGET)
m.rearm()
for _ in range(BUDGET - 1):
    m.frame(write_succeeds=False, engine_kept_our_value=False)
check(m.frame(write_succeeds=False, engine_kept_our_value=False) == "exhausted",
      "P4: budget did not exhaust")
check(m.frame(write_succeeds=False, engine_kept_our_value=False) == "abstain",
      "P4: exhausted writer restarted without a new gesture")
m.rearm()
check(m.frame(write_succeeds=False, engine_kept_our_value=False) == "retry",
      "P4: re-arm after exhaustion did not restart the writer")

# --- P5: sustain requires an armed writer -----------------------------------
m = SustainModel(BUDGET, sustain_writer=1, memory_writer_armed=0)
m.arm()
check(m.remaining == 0, "P5: sustain armed without the memory writer")
check(m.sustain_writer == 0, "P5: sustainWriter survived without writer arm")

# --- Source pinning: the model must track the shipped code ------------------
runtime = RUNTIME.read_text(encoding="utf-8", errors="replace")
header = HEADER.read_text(encoding="utf-8", errors="replace")

budget_match = re.search(r"WZAimRuntimeMaxSustainFrames\s*=\s*(\d+)", header)
check(budget_match is not None, "P0: WZAimRuntimeMaxSustainFrames is not declared")
if budget_match:
    check(int(budget_match.group(1)) == BUDGET,
          f"P0: budget drifted to {budget_match.group(1)}, model asserts {BUDGET}")

check("uint8_t sustainWriter;" in header, "P0: sustainWriter missing from the ABI")
check("void ArmSustainLocked(" in runtime, "P0: ArmSustainLocked missing")
check("void EndSustainLocked(" in runtime, "P0: EndSustainLocked missing")
check("bool SustainStillHoldingLocked(" in runtime,
      "P0: SustainStillHoldingLocked missing")

# The abort-on-first-failure shape is what caused the defect.
abort_shape = re.search(
    r"const bool wrote =\s*transaction\.status == "
    r"WZAimPolicy::PairWriteStatus::Success;\s*if \(!wrote\) \{\s*"
    r"\(void\)RestoreOriginal",
    runtime)
check(abort_shape is None, "P0: abort-on-first-rejected-write reappeared")

# Sustain must outlive ClearGestureStateLocked.
clear_body = re.search(
    r"void ClearGestureStateLocked\(\) \{(.*?)\n\}", runtime, re.S)
check(clear_body is not None, "P0: ClearGestureStateLocked not found")
if clear_body:
    check("Sustain" not in clear_body.group(1),
          "P0: ClearGestureStateLocked now ends sustain (P4 regression)")

# The gesture-abstain guard must require sustain to be spent.
check("!gGestureActive && gSustainFramesRemaining == 0" in runtime,
      "P0: gesture-abstain guard does not consult sustain")

# Exhaustion must be sticky, or a losing binding spins forever.
check("bool gSustainExhausted = false;" in runtime,
      "P0: sticky exhaustion state missing")
check("gSustainExhausted = true;" in runtime,
      "P0: exhaustion is never latched")
check("if (gSustainExhausted || (!gGestureActive" in runtime,
      "P0: the write path does not honour latched exhaustion")
check("void RearmSustainLocked(" in runtime,
      "P0: exhaustion cannot be cleared for a new aim attempt")
check("RearmSustainLocked();" in runtime,
      "P0: the gesture arm does not re-arm sustain")

# HUD must actually enable it.
hud = (ROOT / "lara" / "kexploit" / "WZHUDBridge.mm").read_text(
    encoding="utf-8", errors="replace")
check("aim.sustainWriter=1;" in hud, "P0: HUD does not enable the sustained writer")

if failures:
    for f in failures:
        print("FAIL: " + f)
    sys.exit(1)

print("WZ aim sustain behavioural oracle passed: "
      "bounded, sticky, refill-on-success, soft-clear-safe, gated")
