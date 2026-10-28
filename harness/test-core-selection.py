#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 John Knipper
"""Reject stale SDK/source combinations through the real Hosted source guard."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="pomaros-core-selection-") as tmp:
    root = Path(tmp).resolve()
    product, source, build = (root / x for x in ("product", "source", "build"))
    for p in (product / "graft", source, build):
        p.mkdir(parents=True)
    shutil.copy2(ROOT / "graft/check-core", product / "graft/check-core")
    def git(*args):
        return subprocess.check_output(["git", "-C", str(source), *args], text=True).strip()
    git("init", "-q")
    git("config", "user.name", "Fixture")
    git("config", "user.email", "fixture@example.invalid")
    (source / "source.c").write_text("/* fixture */\n")
    git("add", ".")
    git("commit", "-qm", "Fixture")
    revision = git("rev-parse", "HEAD")
    (product / "CORE.lock").write_text("CORE_REVISION=" + revision + "\nCORE_TARGET=darwin-aarch64\nCORE_X18_POLICY=reserved\n")
    (build / "Makefile").write_text("SRCDIR := " + str(source) + "\n")
    env = dict(os.environ, AROS_SRC=str(source), AROS_BUILD=str(build))
    def check(expected, *args):
        result = subprocess.run([str(product / "graft/check-core"), *args], env=env,
                                capture_output=True, text=True, timeout=10)
        assert (result.returncode == 0) == expected, result.stdout + result.stderr
        return result.stderr
    first_error = check(False)
    assert "configured unknown" in first_error, first_error
    stamp = build / ".pomaros-configure-core"
    stamp.write_text("0" * 40 + ":other-config\n")
    assert "Build revision mismatch" in check(False)
    check(True, "--source-only")
    stamp.write_text(revision + ":matching-config\n")
    check(True)
    (build / "Makefile").write_text("SRCDIR := /foreign/source\n")
    assert "another source" in check(False)
    (build / "Makefile").write_text("SRCDIR := " + str(source) + "\n")
    (source / "source.c").write_text("/* modified */\n")
    assert "visible changes" in check(False)
print("Hosted core selection: PASS (missing/stale stamp, source-only, matching SDK, foreign source, dirty source)")
