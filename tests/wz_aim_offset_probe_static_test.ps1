$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

$probe = Get-Content -Raw (Join-Path $root 'lara/kexploit/wz/WZAimOffsetProbe.mm')
$header = Get-Content -Raw (Join-Path $root 'lara/kexploit/wz/WZAimOffsetProbe.h')
$observer = Get-Content -Raw (Join-Path $root 'lara/kexploit/wz/WZAimObserver.mm')
$observerHeader = Get-Content -Raw (Join-Path $root 'lara/kexploit/wz/WZAimObserver.h')
$swift = Get-Content -Raw (Join-Path $root 'lara/classes/laramgr.swift')
$bridge = Get-Content -Raw (Join-Path $root 'lara/lara-Bridging-Header.h')

function Need([string]$text, [string]$pattern, [string]$message) {
    if ($text -notmatch $pattern) { throw "FAIL: $message" }
}

function Reject([string]$text, [string]$pattern, [string]$message) {
    if ($text -match $pattern) { throw "FAIL: $message" }
}

# The probe exists to replace guessed offsets with resolved ones.
Need $header 'WZAimOffsetProbeSnapshot' 'probe snapshot ABI missing'
Need $header 'wzaim_offset_probe_poll' 'probe poll API missing'
Need $header 'wzaim_offset_probe_reset' 'probe reset API missing'
Need $header 'wzaim_offset_probe_copy_snapshot' 'probe snapshot accessor missing'

# It must report the resolved truth AND echo the constants for a direct diff.
Need $header 'uint32_t indicatorPosition;' 'probe does not report the resolved indicator position offset'
Need $header 'uint32_t expectedIndicatorPosition;' 'probe does not echo the position constant for diffing'
Need $header 'uint32_t expectedIndicatorDirection;' 'probe does not echo the direction constant for diffing'
Need $header 'uint32_t expectedIndicatorOrigin;' 'probe does not echo the origin constant for diffing'
Need $header 'uint32_t actorPosition;' 'probe does not report the resolved actor position offset'
Need $header 'uint32_t expectedActorPosition;' 'probe does not echo the actor position constant for diffing'
Need $header 'uint8_t exact;' 'probe does not publish a match verdict'

# Stage machine so a failure is diagnosable rather than silent.
Need $header 'int32_t stage;' 'probe has no staged progress field'
Need $probe 'PublishStage\(&snapshot, 9, "complete"\)' 'probe has no terminal success stage'
Need $probe '"no-host-actor"' 'probe does not distinguish a missing host actor'
Need $probe '"actor-class"' 'probe does not distinguish an unavailable ActorLinker class'
Need $probe '"indicator-fields"' 'probe does not distinguish unresolved indicator fields'

# Field names must match the real 11.4.10103 metadata.
Need $probe 'useSkillPosition' 'probe does not resolve useSkillPosition'
Need $probe '_useSkillDirection' 'probe does not resolve _useSkillDirection'
Need $probe 'rootPosition' 'probe does not resolve rootPosition'
Need $probe 'ActorLinker' 'probe does not resolve ActorLinker'
Need $probe 'SkillControlIndicator' 'probe does not resolve SkillControlIndicator'
Need $probe 'm_skillBtnMgr' 'probe does not resolve the indicator manager field'

# The resolved offsets must be read through FieldInfo.offset, not assumed.
Need $probe 'ResolveInstanceFieldLocked' 'probe does not reflect instance fields'
Need $probe 'kFieldOffsetOffset' 'probe does not read the FieldInfo value offset'

# Pure read: the probe must never write to the target, and must never arm,
# bind, gesture or otherwise mutate the runtime.  Reading the write-health
# view is explicitly permitted -- it is the whole point of the combined
# verdict -- so the guard targets the mutating entry points by name.
Reject $probe '\bwz_write\s*\(' 'offset probe writes to the target'
Reject $probe 'wzaim_runtime_(attach|detach|apply_config|bind_verified_indicator|revoke_observer|set_gesture_active|consume_snapshot|set_skill_config|clear_skill_config)\s*\(' 'offset probe mutates the aim runtime'
Need $probe 'wzaim_runtime_copy_write_health\(' 'probe does not read the write-health view for the combined verdict'
Reject $probe 'RemoteCall|doRemoteCall|thread_attach|thread_detach' 'offset probe executes target-process calls'

# Combined verdict: one line must say whether a missing aim is an offset
# problem or a write-race problem, because the fixes are opposite.
Need $probe 'wz\.aim\.verdict' 'probe publishes no combined offset/writer verdict'
Need $probe 'OFFSETS-WRONG' 'verdict does not name the offset failure'
Need $probe 'WRITER-GAVE-UP' 'verdict does not name the exhausted writer'
Need $probe 'AIM-LIVE' 'verdict does not confirm a live external write'
Need $probe 'WRITER-TRYING' 'verdict does not distinguish an in-progress writer'
Need $probe 'WRITER-NOT-ARMED' 'verdict does not distinguish an unarmed writer'
$runtimeHeader = Get-Content -Raw (Join-Path $root 'lara/kexploit/wz/WZAimRuntime.h')
Need $runtimeHeader 'WZAimWriteHealth' 'write-health view is not declared in the runtime ABI'
Need $runtimeHeader 'uint8_t holding;' 'write-health view does not report whether the engine kept our value'
Need $runtimeHeader 'wzaim_runtime_copy_write_health' 'write-health accessor is not declared'

# It shares the single host-actor proof instead of keeping its own.
Need $observerHeader 'wzaim_observer_copy_host_actor' 'observer does not expose the shared host-actor proof'
Need $observer 'wzaim_observer_copy_host_actor' 'observer does not implement the shared host-actor proof'
Need $probe 'wzaim_observer_copy_host_actor' 'probe does not consume the shared host-actor proof'

# Wiring: bridging header, worker loop, lifecycle arm/reset.
Need $bridge 'wz/WZAimOffsetProbe.h' 'probe is not exposed to Swift'
Need $swift 'wzOffsetProbeArmed' 'probe is not gated by a Swift-side arm flag'
Need $swift 'wzaim_offset_probe_poll\(\)' 'probe is not polled by the WZ worker'
Need $swift 'wzaim_offset_probe_reset\(\)' 'probe is not reset with the WZ lifecycle'
Need $swift 'aim\.offsetprobe' 'probe has no user-visible enable setting'
Need $swift 'wzaim_observer_poll\(\)[\s\S]{0,600}wzaim_offset_probe_poll\(\)' 'probe is not scheduled after the observer proof'

'PASS: WZ aim offset probe static checks'
