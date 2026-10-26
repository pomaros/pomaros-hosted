#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 John Knipper
"""Reject empty desktop frames without acquiring a live harness lease."""
from pathlib import Path
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='pomaros-frame-test-') as tmp:
    root = Path(tmp)
    lock = root/'live-harness-lock'
    lock.mkdir()
    env = dict(os.environ, AROS_HARNESS_LOCK_DIR=str(lock))
    for name, rgb in [('black', b'\0\0\0'), ('background', bytes([153])*3),
                      ('red', b'\xff\0\0')]:
        image = root/(name+'.ppm')
        image.write_bytes(b'P6\n800 600\n255\n' + rgb*800*600)
        result = subprocess.run([str(ROOT/'graft/desktop-smoke'), '--check-frame',
                                 str(image)], env=env, capture_output=True, text=True, timeout=10)
        assert result.returncode == 1, (name, result.stdout, result.stderr)
        assert 'desktop-frame result=FAIL' in result.stdout
        assert lock.is_dir(), 'offline check removed another harness lease'
    print('desktop-oracle result=PASS cases=3 scope=empty-frame-refusal-and-offline-lease-isolation')
