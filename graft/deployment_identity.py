#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 John Knipper
"""Compare arm64 Mach-O build/deployment bytes across code signing."""
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile


def commands(data):
    if len(data) < 32 or struct.unpack_from('<II', data) != (0xfeedfacf, 0x100000c):
        raise ValueError('not thin arm64 Mach-O')
    count, size = struct.unpack_from('<II', data, 16)
    end, offset = 32 + size, 32
    if end > len(data):
        raise ValueError('truncated load commands')
    result = []
    for _ in range(count):
        if offset + 8 > end:
            raise ValueError('truncated command')
        kind, length = struct.unpack_from('<II', data, offset)
        if length < 8 or offset + length > end:
            raise ValueError('invalid command size')
        result.append((kind, offset, length))
        offset += length
    if offset != end:
        raise ValueError('inconsistent command extent')
    return result


def run(*args):
    subprocess.run(args, check=True, capture_output=True, timeout=10)


def normalized(path, copy):
    data = path.read_bytes()
    entries = commands(data)
    shutil.copyfile(path, copy)
    if any(kind == 0x1d for kind, _, _ in entries):
        run('/usr/bin/codesign', '--remove-signature', str(copy))
    data = bytearray(copy.read_bytes())
    found = False
    for kind, offset, length in commands(data):
        if kind == 0x19 and data[offset+8:offset+24].rstrip(b'\0') == b'__LINKEDIT':
            if found or length < 72:
                raise ValueError('invalid linkedit segment')
            found = True
            _, vmsize, fileoff, filesize = struct.unpack_from('<QQQQ', data, offset+24)
            if filesize > vmsize or fileoff + filesize > len(data):
                raise ValueError('invalid linkedit extent')
            # Removing a signature leaves its enlarged virtual reservation.
            # Retain all file data and every other load-command field.
            struct.pack_into('<Q', data, offset+32, filesize)
    if not found:
        raise ValueError('missing linkedit segment')
    return data


def same(source, deployed):
    if any(not p.is_file() or p.stat().st_size > 256 * 1024 * 1024
           for p in (source, deployed)):
        return False
    try:
        commands(source.read_bytes())
        commands(deployed.read_bytes())
        run('/usr/bin/codesign', '--verify', '--strict', str(deployed))
        with tempfile.TemporaryDirectory(prefix='pomaros-identity-') as tmp:
            return normalized(source, Path(tmp)/'source') == normalized(deployed, Path(tmp)/'deployed')
    except (OSError, ValueError, struct.error, subprocess.SubprocessError):
        return False


if __name__ == '__main__':
    if len(sys.argv) != 3:
        raise SystemExit('usage: deployment_identity.py SOURCE DEPLOYED')
    raise SystemExit(0 if same(Path(sys.argv[1]), Path(sys.argv[2])) else 1)
