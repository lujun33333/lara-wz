"""Host-side static gate for the 12.1 read-only root-migration candidate.

Usage: python tests/wz_profile_121_static_test.py PATH_TO_12_1_UnityFramework
This does not replace an iOS build or a device readback.
"""
import pathlib
import re
import struct
import sys


SOURCE = pathlib.Path(__file__).resolve().parents[1] / "lara/classes/laramgr.swift"
EXPECTED_UUID = bytes.fromhex("1b2f8a2218373218b3a86e853cdb5076")
EXPECTED_MATRIX_ROOT = 0x138A2848


def macho_header(path):
    with open(path, "rb") as stream:
        header = stream.read(1 << 20)
    assert struct.unpack_from("<I", header)[0] == 0xFEEDFACF
    cursor = 32
    uuid = None
    bss = None
    for _ in range(struct.unpack_from("<I", header, 16)[0]):
        cmd, size = struct.unpack_from("<II", header, cursor)
        if cmd == 0x1B:
            uuid = header[cursor + 8:cursor + 24]
        elif cmd == 0x19:
            count = struct.unpack_from("<I", header, cursor + 64)[0]
            section = cursor + 72
            for _ in range(count):
                name = header[section:section + 16].rstrip(b"\0")
                if name == b"__bss":
                    bss = struct.unpack_from("<QQ", header, section + 32)
                section += 80
        cursor += size
    return uuid, bss


def root_reference(path, adrp_rva, ldr_delta=4):
    with open(path, "rb") as stream:
        stream.seek(adrp_rva)
        first = struct.unpack("<I", stream.read(4))[0]
        stream.seek(adrp_rva + ldr_delta)
        second = struct.unpack("<I", stream.read(4))[0]
    assert first & 0x9F000000 == 0x90000000  # ADRP
    assert second & 0xFFC00000 == 0xF9400000  # LDR X
    reg = first & 31
    assert (second >> 5) & 31 == reg
    immediate = (((first >> 5) & 0x7FFFF) << 2) | ((first >> 29) & 3)
    if immediate & (1 << 20):
        immediate -= 1 << 21
    return (adrp_rva & ~0xFFF) + (immediate << 12) + (((second >> 10) & 0xFFF) << 3)


def qword(path, offset):
    with open(path, "rb") as stream:
        stream.seek(offset)
        return struct.unpack("<Q", stream.read(8))[0]


def main(path):
    source = SOURCE.read_text(encoding="utf-8")
    uuid_values = re.search(r"private let wzProfile121UUID: \[UInt8\] = \[([^]]+)\]", source)
    assert uuid_values is not None
    source_uuid = bytes(int(x, 16) for x in re.findall(r"0x([0-9a-fA-F]{2})", uuid_values.group(1)))
    assert source_uuid == EXPECTED_UUID
    assert "private let wzProfile121MatrixRVA: UInt64 = 0x138A2848" in source
    assert re.search(r"let profileReadable = imageValid &&\s+self\.wzCollectorPagesReadable\(base,\s+profile121: image\.profile121\)", source)
    assert "let aimFunctional = valid && !image.profile121" in source
    assert "wzesp_select_profile121(image.profile121 ? 1 : 0)" in source
    assert "self.startWZLoop()" in source
    assert "self.startWZDiagnostic121Loop" not in source
    assert "wzaim_observer_stop()\n                    wzaim_runtime_detach()" in source
    frame = source[source.index("    private func wzFrame()"):]
    new_mask = frame[frame.index("if request.4 {"):frame.index("let drawEnabled")]
    assert "WZESP_SHOW_AVATAR" in new_mask and "WZESP_SHOW_BOX" in new_mask
    assert all(forbidden not in new_mask for forbidden in (
        "WZESP_COLLECT_AIM", "WZESP_AUTO_KILL", "WZESP_SHOW_SKILL",
        "WZESP_SHOW_HERO_VISION", "WZESP_SHOW_SOLDIER_VISION"))
    assert "if !request.4 {\n            scheduleWZReaders" in frame
    collector = (SOURCE.parents[2] / "lara/kexploit/wz/YuanbaoCollector.mm").read_text(encoding="utf-8")
    projection = (SOURCE.parents[2] / "lara/kexploit/wz/KoiProjection.mm").read_text(encoding="utf-8")
    assert "kActorRootRVA121 = 0x13E5C698" in collector
    assert "kMonsterRootRVA121 = 0x133CD510" in collector
    assert "kKoiMatrixRootRVA121 = 0x138A2848" in projection
    uuid, bss = macho_header(path)
    assert uuid == EXPECTED_UUID, (uuid, EXPECTED_UUID)
    assert bss is not None and bss[0] <= EXPECTED_MATRIX_ROOT < bss[0] + bss[1]
    # These matched a different singleton, as disproved by the device log.
    assert root_reference(path, 0x1C567C) == 0x139F20F0
    assert root_reference(path, 0x74416F0) == 0x139F20F0
    assert EXPECTED_MATRIX_ROOT != 0x139F20F0
    assert root_reference(path, 0x8C23B3C) == 0x12FA94D8
    assert root_reference(path, 0x8C23B4C, 8) == 0x130EB9B0
    assert qword(path, 0x12FA94D8) == 0x13E5C698
    assert qword(path, 0x130EB9B0) == 0x133CD510
    assert qword(path, 0x12FA94E0) == 0x8C23B30
    assert bss[0] <= 0x13E5C698 < bss[0] + bss[1]
    assert bss[0] <= 0x133CD510 < bss[0] + bss[1]
    old_path = path.parent.parent / "wz11-analysis" / "UnityFramework"
    if old_path.exists():
        assert root_reference(old_path, 0x8C36F60) == 0x123DFAE8
        assert root_reference(old_path, 0x8C36F70, 8) == 0x125130D0
        assert qword(old_path, 0x123DFAE8) == 0x1325A6C0
        assert qword(old_path, 0x125130D0) == 0x127E3240
        assert qword(old_path, 0x123DFAF0) == 0x8C36F54
    print("12.1 static gate OK: UUID, corrected camera-root wiring, actor/monster table match")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: wz_profile_121_static_test.py PATH_TO_12_1_UnityFramework")
    main(pathlib.Path(sys.argv[1]))
