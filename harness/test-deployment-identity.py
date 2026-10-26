#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 John Knipper
"""Exercise deployment identity with real arm64 binaries and code signatures."""
from pathlib import Path
import runpy
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
same = runpy.run_path(str(ROOT/'graft/deployment_identity.py'))['same']


def run(*args):
    subprocess.run(args, check=True, capture_output=True, timeout=30)


with tempfile.TemporaryDirectory(prefix='pomaros-deployment-test-') as tmp:
    root = Path(tmp)
    source, deployed = root/'source', root/'deployed'
    c = root/'probe.c'
    c.write_text('const char proof[]="POMAROS_DEPLOYMENT_PROOF";\nint main(void){return proof[0]==\'P\'?0:1;}\n')
    run('/usr/bin/clang', '-arch', 'arm64', '-O0', str(c), '-o', str(source))
    shutil.copyfile(source, deployed)
    run('/usr/bin/codesign', '-s', '-', '-f', '-o', 'runtime', '--entitlements',
        str(ROOT/'graft/aros-host.entitlements.plist'), str(deployed))
    assert same(source, deployed), 'valid signing-only change refused'
    good = deployed.read_bytes()
    changed = good.replace(b'POMAROS_DEPLOYMENT_PROOF', b'QOMAROS_DEPLOYMENT_PROOF')
    assert changed != good
    deployed.write_bytes(changed)
    assert not same(source, deployed), 'invalid signature accepted'
    run('/usr/bin/codesign', '-s', '-', '-f', str(deployed))
    assert not same(source, deployed), 'validly signed changed data accepted'
    deployed.write_bytes(good[:128])
    assert not same(source, deployed), 'truncated Mach-O accepted'
    deployed.write_text('a configuration file')
    assert not same(source, deployed), 'non-Mach-O accepted'
    deployed.unlink()
    assert not same(source, deployed), 'missing deployment accepted'
    print('deployment-identity result=PASS cases=6 scope=real-arm64-code-signing-and-mutation')
