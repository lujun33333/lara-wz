#include <cassert>
#include <cstdint>
#include <cstring>
#include <string>
#include <unordered_map>

#include "../lara/kexploit/wz/WZAimRuntime.h"

static std::unordered_map<uint64_t, uint8_t> memory;
static unsigned writeCalls = 0;

extern "C" bool wz_transport_ready(void) { return true; }
extern "C" bool wz_transport_can_write(void) { return true; }
extern "C" const char *wz_transport_name(void) { return "mapped-pages"; }
extern "C" int wz_connected_pid(void) { return 7; }
extern "C" uint64_t wz_session_generation(void) { return 11; }
extern "C" long wz_read(uint64_t address, void *output, size_t size) {
    auto *bytes = static_cast<uint8_t *>(output);
    for (size_t index = 0; index < size; ++index) {
        const auto found = memory.find(address + index);
        if (found == memory.end()) return -1;
        bytes[index] = found->second;
    }
    return static_cast<long>(size);
}
extern "C" void wzaim_runtime_revoke_observer(void) { ++writeCalls; }
extern "C" void wzaim_runtime_set_gesture_active(bool) { ++writeCalls; }
extern "C" bool wzaim_runtime_is_ready(void) { return false; }
extern "C" bool wzaim_runtime_bind_verified_indicator(
    const WZAimObservedIndicator *) { ++writeCalls; return false; }

#include "../lara/kexploit/wz/WZAimObserver.mm"

static void put(uint64_t address, const char *bytes, size_t length) {
    for (size_t index = 0; index < length; ++index)
        memory[address + index] = static_cast<uint8_t>(bytes[index]);
}

int main() {
    std::string parsed;
    constexpr uint64_t tail = UINT64_C(0x1A0000FF4);
    constexpr char shortName[] = "ActorLinker";
    put(tail, shortName, sizeof(shortName));
    assert(ReadCString(tail, &parsed) && parsed == "ActorLinker");

    constexpr uint64_t unterminated = UINT64_C(0x1A0010FFE);
    constexpr char twoBytes[]{'A', 'B'};
    put(unterminated, twoBytes, sizeof(twoBytes));
    assert(!ReadCString(unterminated, &parsed));

    constexpr uint64_t longName = UINT64_C(0x1A0020000);
    char bytes[128];
    std::memset(bytes, 'X', sizeof(bytes));
    put(longName, bytes, sizeof(bytes));
    assert(!ReadCString(longName, &parsed));
    bytes[127] = 0;
    put(longName, bytes, sizeof(bytes));
    assert(ReadCString(longName, &parsed) && parsed.size() == 127);
    assert(writeCalls == 0);
}
