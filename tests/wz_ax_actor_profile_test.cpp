#include "../lara/kexploit/wz/YuanbaoCollector.mm"
#include <cassert>
#include <map>
static std::map<uint64_t, uint8_t> memory;
template<class T> void put(uint64_t address, const T &value) {
    const auto *bytes = reinterpret_cast<const uint8_t *>(&value);
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
extern "C" const char *wz_transport_name() { return "mock"; }
extern "C" long wz_read_fresh_root(uint64_t address, void *out, size_t size, uint64_t *) {
    return wz_read(address, out, size);
}
extern "C" bool KoiProjectionMatrixLooksValid(const float *) { return true; }
int main() {
    constexpr uintptr_t unity = 0x100000000, root = 0x110000000;
    constexpr uintptr_t manager = 0x120000000, heroes = 0x130000000;
    constexpr uintptr_t soldiers = 0x140000000;
    MemoryReader reader;
    put(unity + 0x1325A6C0, root);
    put(root + 0x138, manager);
    put(manager + 0x78, heroes);
    put(manager + 0x94, int32_t(20));
    put(manager + 0x120, soldiers);
    put(manager + 0x13C, int32_t(128));
    KoiActorTables tables{};
    KoiRuntimeDiagnostics diagnostics{};
    assert(ResolveActorTables(reader, unity, true, &tables, &diagnostics));
    assert(tables.heroTableValid && tables.heroCount == 20 && tables.soldierCount == 128);
    put(manager + 0x94, int32_t(21));
    put(manager + 0x13C, int32_t(129));
    put(manager + 0x108, soldiers);
    put(manager + 0x124, int32_t(10)); // old alternative must not rescue invalid AX table
    tables = {};
    assert(ResolveActorTables(reader, unity, true, &tables, &diagnostics));
    assert(!tables.heroTableValid && tables.soldierEntries == 0);
    std::vector<uintptr_t> actors;
    for (int i = 0; i < 12; ++i) {
        const uintptr_t actor = 0x150000000 + i * 0x1000;
        actors.push_back(actor);
        int32_t header[4]{101+i, 0, 0, 2};
        put(actor + 0x50, header); // only 16B mapped: former 544B read fails
    }
    KoiProjectionState projection{}; projection.valid = 1; projection.matrix[0] = 1;
    KoiHostIdentity host{};
    std::vector<KoiHeroHeader> headers;
    uint32_t failures = 0;
    assert(CollectHeroHeaders(reader, unity, actors, projection, &host, &failures, &headers));
    assert(headers.size() == 10 && host.camp == 1);
    put(actors[0] + 0x50, int32_t(100));
    put(actors[1] + 0x50, int32_t(801));
    put(actors[2] + 0x5C, int32_t(1));
    put(actors[3] + 0x50, int32_t(105)); // duplicate of actor index 4
    headers.clear();
    CollectHeroHeaders(reader, unity, actors, projection, &host, &failures, &headers);
    assert(headers.size() == 8);
    uintptr_t cursor = 0x160000000;
    put(unity + 0x126DAF40, cursor);
    for (uintptr_t offset : {uintptr_t(0xB0), uintptr_t(8), uintptr_t(0x1A0), uintptr_t(8), uintptr_t(0x30)}) {
        put(cursor + offset, cursor + 0x1000); cursor += 0x1000;
    }
    put(cursor + 0x750, int32_t(0x4A65));
    std::array<uint8_t, 0x1C8> aux{};
    for (int32_t i = 0; i < 5; ++i) {
        const int32_t id = 101 + i;
        std::memcpy(aux.data() + i * 0x38, &id, sizeof(id));
    }
    put(cursor + 0x220, aux);
    gAXAuxiliaryTable = {};
    gAXAuxiliaryTable.started = true;
    UpdateAXAuxiliaryTable(reader, unity);
    assert(gAXAuxiliaryTable.valid && gAXAuxiliaryTable.address == cursor + 0x220);
}
