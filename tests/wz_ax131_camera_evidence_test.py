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
    source = pathlib.Path(__file__).resolve().parents[1]
    projection = (source / "lara/kexploit/wz/KoiProjection.mm").read_text(encoding="utf-8")
    swift = (source / "lara/classes/laramgr.swift").read_text(encoding="utf-8")
    diagnostics = (source / "lara/kexploit/wzesp.mm").read_text(encoding="utf-8")
    assert "kKoiMatrixRootRVA121 = 0x138A2848" in projection
    assert "wzProfile121MatrixRVA: UInt64 = 0x138A2848" in swift
    assert "wzesp_profile121() ? 0x138A2848 : 0x12CA9580" in diagnostics
    print("AX 1.3.1 camera evidence OK: sample hash, root instruction, decoded chain, consumers")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: wz_ax131_camera_evidence_test.py AX_1.3.1.ipa")
    main(pathlib.Path(sys.argv[1]))
