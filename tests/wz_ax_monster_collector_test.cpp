// Run the actual production Gather path against a sparse synthetic memory map.
#include "../lara/kexploit/wz/YuanbaoCollector.mm"
#include <cassert>
#include <map>
static std::map<uint64_t, uint8_t> memory;
template<class T> void put(uint64_t address, const T &value) {
    const uint8_t *bytes = reinterpret_cast<const uint8_t *>(&value);
    for (size_t i = 0; i < sizeof(T); ++i) memory[address + i] = bytes[i];
}
extern "C" long wz_read(uint64_t address, void *out, size_t size) {
    auto *bytes = static_cast<uint8_t *>(out);
    for (size_t i = 0; i < size; ++i) {
        auto found = memory.find(address + i);
        if (found == memory.end()) return -1;
        bytes[i] = found->second;
    }
    return static_cast<long>(size);
}

extern "C" long wz_read_fresh_root(uint64_t address, void *out, size_t size,
                                   uint64_t *) { return wz_read(address, out, size); }
extern "C" const char *wz_transport_name(void) { return "synthetic-read-only"; }

int main() {
    constexpr uintptr_t unity = 0x160000000, root = 0x170000000;
    constexpr uintptr_t owner = 0x180000000, state = 0x190000000;
    constexpr uintptr_t entries = 0x1A0000000, node = 0x1B0000000;
    put(unity + 0x127E3240, root); put(root + 0x3B8, owner);
    put(owner + 0x88, state); put(state + 0x140, entries);
    // Slot 0 is intentionally absent: no slot renumbering is allowed.
    put(entries + 4 * 24, node);
    put(node + 0x2B8, int32_t(10800)); put(node + 0x2C0, int32_t(-2000));
    put(node + 0x240, uint32_t(1000));
    YuanbaoCollectorInput input{}; input.featureMask = KoiFeatureMonster;
    input.screenWidth = 1000; input.screenHeight = 500;
    input.minimapOriginX = 50; input.minimapOriginY = 204;
    KoiProjectionState projection{}; KoiProjectionReset(&projection);
    KoiRuntimeDiagnostics diagnostics{}; KoiEntity entities[19]{};
    assert(YuanbaoCollectorGather(unity, &input, entities, 19, &projection, &diagnostics) == 19);
    for (int i = 0; i < 19; ++i) assert(entities[i].axMonsterSlot == i);
    assert(entities[4].worldX == 10.8f && entities[4].worldZ == -2.0f);
    assert(entities[4].primitive == KoiPrimitiveMonsterPoint);
    // Before discovery exhaustion, node+0x240 is deliberately not consumed.
    gAXAuxiliaryTable.exhausted = true;
    assert(YuanbaoCollectorGather(unity, &input, entities, 19, &projection, &diagnostics) == 19);
    assert(entities[4].primitive == KoiPrimitiveMonsterTimer);
    assert(entities[4].monsterRespawnSeconds == 4);
    assert(entities[5].axMonsterSlot == 5 && entities[5].primitive == KoiPrimitiveMonsterPoint);
    // An available auxiliary sample wins over the direct-memory timer.
    gAXAuxiliaryTable.valid = true; gAXAuxiliaryTable.address = 0x1C0000000;
    gAXAuxiliaryTable.nextRefresh = UINT64_MAX;
    const uint32_t timer = 2000;
    std::memcpy(gAXAuxiliaryTable.bytes.data() + 0x110 + 4 * 12, &timer, 4);
    assert(YuanbaoCollectorGather(unity, &input, entities, 19, &projection, &diagnostics) == 19);
    assert(entities[4].monsterRespawnSeconds == 5);
}
