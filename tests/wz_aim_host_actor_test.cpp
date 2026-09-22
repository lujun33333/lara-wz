#include "../lara/kexploit/wz/KoiProjection.h"
#include "../lara/kexploit/wz/WZAimObserver.h"
#include "../lara/kexploit/wzmem.h"

#include <cassert>
#include <cstdint>
#include <cstring>
#include <unordered_map>

static std::unordered_map<uint64_t, uint8_t> memory;
static uint64_t liveGeneration = 7;
static uint32_t observerCalls = 0;
static uint64_t observedActor = 0;
static int32_t observedHero = 0;
static int32_t observedCamp = 0;

template <typename T>
static void put(uint64_t address, const T &value) {
    const auto *bytes = reinterpret_cast<const uint8_t *>(&value);
    for (size_t index = 0; index < sizeof(value); ++index) {
        memory[address + index] = bytes[index];
    }
}

static void putBytes(uint64_t address, const void *value, size_t size) {
    const auto *bytes = static_cast<const uint8_t *>(value);
    for (size_t index = 0; index < size; ++index) {
        memory[address + index] = bytes[index];
    }
}

extern "C" bool wz_transport_ready(void) { return true; }
extern "C" uint64_t wz_session_generation(void) { return liveGeneration; }
extern "C" long wz_read(uint64_t address, void *output, size_t size) {
    auto *bytes = static_cast<uint8_t *>(output);
    for (size_t index = 0; index < size; ++index) {
        const auto found = memory.find(address + index);
        if (found == memory.end()) return -1;
        bytes[index] = found->second;
    }
    return static_cast<long>(size);
}
extern "C" long wz_read_fresh_root(uint64_t address, void *output,
                                    size_t size, uint64_t *rebuildCount) {
    if (rebuildCount != nullptr) *rebuildCount = 1;
    return wz_read(address, output, size);
}
extern "C" bool wzaim_observer_set_host_actor(uint64_t,
                                                uint64_t actor,
                                                int32_t hero,
                                                int32_t camp) {
    ++observerCalls;
    observedActor = actor;
    observedHero = hero;
    observedCamp = camp;
    return true;
}
extern "C" bool KoiProjectionMatrixLooksValid(const float matrix[16]) {
    return matrix != nullptr && (matrix[0] != 0.0f || matrix[10] != 0.0f);
}

#include "../lara/kexploit/wz/WZAimHostActor.mm"

static void putIdentity(uint64_t actor, int32_t hero, int32_t camp) {
    uint8_t identity[16]{};
    std::memcpy(identity, &hero, sizeof(hero));
    std::memcpy(identity + 12, &camp, sizeof(camp));
    putBytes(actor + 0x50, identity, sizeof(identity));
}

static void putPosition(uint64_t actor, uint64_t chainBase,
                        int32_t x, int32_t y, int32_t z) {
    const uint64_t first = chainBase;
    const uint64_t second = chainBase + 0x1000;
    const uint64_t third = chainBase + 0x2000;
    const uint64_t terminal = chainBase + 0x3000;
    put(actor + 0x268, first);
    put(first + 0x10, second);
    put(second, third);
    put(third + 0x60, terminal);
    const int32_t position[3]{x, y, z};
    putBytes(terminal, position, sizeof(position));
}

int main() {
    constexpr uint64_t base = 0x180000000;
    constexpr uint64_t root = 0x190000000;
    constexpr uint64_t root2 = 0x190100000;
    constexpr uint64_t manager = 0x191000000;
    constexpr uint64_t manager2 = 0x191100000;
    constexpr uint64_t entries = 0x192000000;
    constexpr uint64_t localActor = 0x193000000;
    constexpr uint64_t otherActor = 0x194000000;

    put(base + 0x1325A6C0, root);
    put(root + 0x138, manager);
    put(manager + 0x78, entries);
    const int32_t heroCount = 2;
    put(manager + 0x94, heroCount);
    put(entries, localActor);
    put(entries + 0x18, otherActor);
    putIdentity(localActor, 196, 1);
    putIdentity(otherActor, 197, 2);
    putPosition(localActor, 0x195000000, 12000, 0, -8000);

    uint64_t cursor = 0x196000000;
    put(base + 0x123FBC88, cursor);
    for (const uint64_t offset : {uint64_t(0x138), uint64_t(0x2C8),
                                  uint64_t(0x48), uint64_t(0x170)}) {
        const uint64_t next = cursor + 0x1000;
        put(cursor + offset, next);
        cursor = next;
    }
    const int32_t hostPosition[3]{12000, 0, -8000};
    putBytes(cursor + 0x150, hostPosition, sizeof(hostPosition));

    KoiProjectionState projection{};
    projection.valid = 1;
    projection.matrix[0] = 1.0f;
    projection.matrix[10] = 1.0f;

    assert(!wzaim_host_actor_poll(7, base, &projection));
    assert(observerCalls == 0);
    assert(wzaim_host_actor_poll(7, base, &projection));
    assert(observerCalls == 1 && observedActor == localActor);
    assert(observedHero == 196 && observedCamp == 1);

    put(base + 0x1325A6C0, root2);
    put(root2 + 0x138, manager2);
    put(manager2 + 0x78, entries);
    put(manager2 + 0x94, heroCount);
    assert(!wzaim_host_actor_poll(7, base, &projection));
    assert(observerCalls == 2 && observedActor == 0);
    assert(wzaim_host_actor_poll(7, base, &projection));
    assert(observerCalls == 3 && observedActor == localActor);

    putIdentity(otherActor, 197, 1);
    putPosition(otherActor, 0x197000000, 13000, 0, -8000);
    assert(!wzaim_host_actor_poll(7, base, &projection));
    assert(observerCalls == 4 && observedActor == 0);

    putIdentity(otherActor, 197, 2);
    assert(!wzaim_host_actor_poll(7, base, &projection));
    liveGeneration = 8;
    assert(!wzaim_host_actor_poll(7, base, &projection));
    assert(observerCalls == 5 && observedActor == 0);
}
