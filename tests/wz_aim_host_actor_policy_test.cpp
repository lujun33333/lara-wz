#include "../lara/kexploit/wz/WZAimHostActorPolicy.h"

#include <cassert>

int main() {
    using namespace WZAimHostActorPolicy;

    const Position host{12.0, 0.0, -8.0};
    CandidateSelection unique{};
    unique.Consider(0x100001000, 196, 1, host, host, 1);
    assert(unique.Unique());
    assert(unique.matches == 1);

    CandidateSelection wrongCamp{};
    wrongCamp.Consider(0x100001000, 196, 2, host, host, 1);
    assert(!wrongCamp.Unique());

    CandidateSelection tooFar{};
    tooFar.Consider(0x100001000, 196, 1,
                    Position{16.0, 0.0, -8.0}, host, 1);
    assert(!tooFar.Unique());

    CandidateSelection ambiguous{};
    ambiguous.Consider(0x100001000, 196, 1, host, host, 1);
    ambiguous.Consider(0x100002000, 197, 1,
                       Position{13.0, 0.0, -8.0}, host, 1);
    assert(!ambiguous.Unique());
    assert(ambiguous.ambiguous && ambiguous.matches == 2);

    StabilityState state{};
    assert(Observe(&state, 7, 0x100010000, 0x100001000, 196, 1) ==
           StabilityResult::Candidate);
    assert(!state.published && state.consecutiveSamples == 1);
    assert(Observe(&state, 7, 0x100010000, 0x100001000, 196, 1) ==
           StabilityResult::Stable);
    assert(state.published && state.consecutiveSamples == 2);
    assert(Observe(&state, 7, 0x100010000, 0x100001000, 196, 1) ==
           StabilityResult::AlreadyStable);

    assert(Observe(&state, 7, 0x100020000, 0x100001000, 196, 1) ==
           StabilityResult::Candidate);
    assert(!state.published && state.consecutiveSamples == 1);
    assert(Observe(&state, 8, 0x100020000, 0x100001000, 196, 1) ==
           StabilityResult::Candidate);
    assert(!state.published && state.generation == 8);
}
