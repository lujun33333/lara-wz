"""Recheck the corrected camera root against the immutable AX 1.3.1 sample.

This checks the reference binary, not a generated fixture. It does not execute
the IPA and does not assert that a real device has rendered a frame.
"""
import hashlib
import pathlib
import struct
import sys
import zipfile


def main(path):
    blob = path.read_bytes()
    assert hashlib.sha256(blob).hexdigest() == (
        "d9c34a0baadefb2c298c6d781cec3860e30470c13160890c78d722a53b0dd7b3")
    with zipfile.ZipFile(path) as archive:
        binary = archive.read("Payload/AX Pro.app/AX Pro")
    assert hashlib.sha256(binary).hexdigest() == (
        "4af683e1e64048329a6ec61172033f7169e996689d2cebd0b1d77eee42a76d42")
    # __text and __data in this exact sample have VA == 0x100000000 + fileoff.
    mov, movk = struct.unpack_from("<II", binary, 0x843FE4)
    assert mov & 0xFFE0001F == 0x52800009
    assert movk & 0xFFE0001F == 0x72A00009
    root = ((mov >> 5) & 0xFFFF) | (((movk >> 5) & 0xFFFF) << 16)
    assert root == 0x138A2848
    # MBA expressions at 0x10083c654..0x10083c6f8 reduce exactly to XOR.
    encoded = struct.unpack_from("<4Q", binary, 0xFB9B40)
    masks = (0x0D021E7926F44F1A, 0x93CD62301661CCBF,
             0x4FAF6EAA070A4278, 0x3F0A15D9CF0D21EF)
    chain = tuple(value ^ mask for value, mask in zip(encoded, masks))
    assert chain == (0xB8, 0, 8, 0x128), chain
    # AX131 actor consumers, not a uniform guessed displacement adjustment.
    def add_immediate(offset):
        instruction = struct.unpack_from("<I", binary, offset)[0]
        assert instruction & 0xFFC00000 == 0x91000000
        return (instruction >> 10) & 0xFFF
    assert add_immediate(0x83F5CC) == 0x28  # configId
    assert add_immediate(0x83EE88) == 0x34  # camp
    assert add_immediate(0x840DFC) == 0x1D0  # health component
    assert add_immediate(0x840E90) == 0xC8  # max HP
    # 0x10083e268..2f8: exact XOR/MBA decoder of the hero position chain.
    encoded_position = struct.unpack_from("<5Q", binary, 0xFB9E20)
    position_masks = (0xDE7886D0356197A6, 0xF901BDA4C3A6E5F9,
                      0x444E4FF28D1E174F, 0x37CA12D07E66A2FD,
                      0xF45B5B05BB4072AA)
    position_chain = tuple(v ^ m for v, m in zip(encoded_position, position_masks))
    assert position_chain == (0xA8, 0x10, 0, 0x60, 0)
    source = pathlib.Path(__file__).resolve().parents[1]
    projection = (source / "lara/kexploit/wz/KoiProjection.mm").read_text(encoding="utf-8")
    swift = (source / "lara/classes/laramgr.swift").read_text(encoding="utf-8")
    diagnostics = (source / "lara/kexploit/wzesp.mm").read_text(encoding="utf-8")
    assert "kKoiMatrixRootRVA121 = 0x138A2848" in projection
    assert "wzProfile121MatrixRVA: UInt64 = 0x138A2848" in swift
    assert "wzesp_profile121() ? 0x138A2848 : 0x12CA9580" in diagnostics
    collector = (source / "lara/kexploit/wz/YuanbaoCollector.mm").read_text(encoding="utf-8")
    assert "wzesp_profile121() != 0 ? 0x28 : 0x50" in collector
    assert "chain121[]{0xA8, 0x10, 0, 0x60}" in collector
    assert "profile121 ? 0x1D0 : 0x1A0" in collector
    assert "profile121 ? 0xC0 : 0x160" in collector
    assert "profile121 ? 0xC8 : 0x170" in collector
    if len(sys.argv) == 3:
        log = pathlib.Path(sys.argv[2]).read_text(encoding="utf-8", errors="replace")
        latest = log[log.rfind("(wz) connected pid="):]
        assert "rva=0x138a2848" in latest and "matrix={stage=ready" in latest
        assert "actor={stage=ready" in latest
        assert "entities=19 items=19" in latest and "slots=10" in latest
    print("AX 1.3.1 camera/actor evidence OK: hashes, instructions, decoded chains, consumers")


if __name__ == "__main__":
    if len(sys.argv) not in (2, 3):
        raise SystemExit("usage: wz_ax131_camera_evidence_test.py AX_1.3.1.ipa [lara.log]")
    main(pathlib.Path(sys.argv[1]))
