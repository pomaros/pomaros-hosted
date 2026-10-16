#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 John Knipper
"""Disassemble captured real JIT blocks; reject computational platform-register use."""
from pathlib import Path
import re
import subprocess
import sys
folder = Path(sys.argv[1]).resolve()
objdump = sys.argv[2]
blocks = sorted(folder.glob('block-*.bin'))
assert blocks, 'no real JIT code captured'
for binary in [*blocks, folder / 'negative.bin']:
    asm = binary.with_suffix('.s'); obj = binary.with_suffix('.o')
    asm.write_text('.text\n.globl _pomaros_jit_block\n_pomaros_jit_block:\n.incbin "' + str(binary) + '"\n')
    subprocess.run(['clang', '-arch', 'arm64', '-c', str(asm), '-o', str(obj)], check=True)
    output = subprocess.check_output([objdump, '-d', str(obj)], text=True)
    binary.with_suffix('.disassembly.txt').write_text(output)
    refs = [line for line in output.splitlines() if re.match(r'\s*[0-9a-f]+:', line) and re.search(r'\b[wx]18\b', line)]
    bad = [line for line in refs if not re.search(r'(stp|ldp)\s+x17,\s*x18,\s*\[sp', line)]
    if binary.name == 'negative.bin':
        assert len(bad) == 1, 'negative control failed to detect add x18'
    else:
        assert not bad, '\n'.join(bad)
print(f'[JIT-X18] emission PASS {len(blocks)} captured blocks; negative control detected')
