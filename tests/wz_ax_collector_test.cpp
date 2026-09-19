// Executes the production AX readers against a byte-addressed mock transport.
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

int main() {
    MemoryReader reader;
    constexpr uintptr_t actor = 0x110000000;
    constexpr uintptr_t pos = 0x120000000;
    constexpr uintptr_t hp = 0x130000000;
    put(actor + 0x268, pos);
    put(pos + 0x10, pos + 0x1000);
    put(pos + 0x1000, pos + 0x2000);
    put(pos + 0x2060, pos + 0x3000);
    const int32_t xyz[3]{1000, 9000, -2000};
    put(pos + 0x3000, xyz);
    put(actor + 0x1A0, hp);
    put(hp + 0x160, int32_t(100 * 8192));
    put(hp + 0x170, int32_t(1000));
    KoiEntity entity{};
    ReadAXEntityState(reader, actor, true, &entity);
    assert(entity.axPositionValid && entity.axWorldX == 1 && entity.axWorldZ == -2);
    assert(entity.axHealthValid && entity.axHealth == 100 && entity.axHealthTotal == 1000);
    assert(!entity.axDead);
    put(hp + 0x160, int32_t(0));
    ReadAXEntityState(reader, actor, true, &entity);
    assert(!entity.axDead);
    ReadAXEntityState(reader, actor, true, &entity);
    assert(entity.axDead);
    put(hp + 0x160, int32_t(100 * 8192));
    ReadAXEntityState(reader, actor, true, &entity);
    assert(entity.axDead);
    ReadAXEntityState(reader, actor, true, &entity);
    assert(!entity.axDead);
    KoiRuntimeDiagnostics diagnostics{};
    diagnostics.hostPositionValid = 1;
    diagnostics.autoKillSampleValid = 1;
    assert(!ReadAXHostPosition(reader, 0x140000000, &diagnostics));
    assert(!diagnostics.hostPositionValid);
    ReadAXAutoKillState(reader, 0x140000000, &diagnostics);
    assert(!diagnostics.autoKillSampleValid);
}
