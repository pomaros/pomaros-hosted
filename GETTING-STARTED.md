# Getting started

A newcomer's path from an empty machine to a running system. If you have never
touched this project, start here and read top to bottom. Deep dives are linked as
you go; you do not need them to get something on screen.

There are two payoffs, cheapest first:

1. **Run a classic 68k Amiga binary** on Apple Silicon — no AROS build, ~2 minutes.
2. **Boot hosted AROS** (AmigaOS) in a live Mac window — one longer build.

---

## 0. What you need

- A **Mac with Apple Silicon** (M1 or newer) running a recent macOS. This is an
  `aarch64-darwin` project; Intel Macs and Linux are not targets.
- **Xcode Command Line Tools**: `xcode-select --install`
- **[Homebrew](https://brew.sh)**.

Everything else is installed in the steps below.

---

## 1. The fast path — run a 68k Amiga program (~2 min)

This needs only *this* repo and Homebrew's LLVM. It builds `run68k`, a
68k→AArch64 JIT that runs self-contained classic-Amiga binaries natively.

```sh
brew install llvm lld
git clone https://github.com/pomaros/pomaros-hosted.git    # this repo
cd pomaros-hosted
make run68k                                            # -> build/run68k
build/run68k hosted/jit68k/apps68k/bin/mandel.exe      # prints a Mandelbrot, exits 0
```

The program's stdout is yours to pipe, its exit code is the program's own `D0`,
and any fault drops a self-contained crash-bundle `.tar.gz`. More sample
programs: [hosted/jit68k/apps68k/README.md](hosted/jit68k/apps68k/README.md).
Full design: [docs/features/68k-jit/](docs/features/68k-jit/design.md).

That is the whole 68k story — no cross-toolchain, no OS build. The rest of this
page is the bigger payoff: booting real AROS.

---

## 2. Get the source — two sibling checkouts

Hosted AROS is built from **two repositories that must sit side by side**:

```
some-parent-dir/
├── pomaros-hosted/     ← THIS repo — the host / graft layer (scripts, host shims, docs)
└── aros-core-pomaros/    ← the AROS OS source (kernel, libraries, Workbench)
```

`pomaros-hosted` is the Mac-side glue. `aros-core-pomaros` contains the shared
AROS sources and the Darwin hosted adaptation. Obtain the source at the exact
revision recorded in `CORE.lock`; repository access is required while the
shared source remains private.

```sh
cd pomaros-hosted
. ./CORE.lock
git clone --branch "$CORE_BRANCH" "$CORE_URL" ../aros-core-pomaros
git -C ../aros-core-pomaros checkout --detach "$CORE_REVISION"
git -C ../aros-core-pomaros submodule update --init --recursive
./graft/check-core
```

The scripts default to `../aros-core-pomaros`, `../Build/pomaros-hosted`, and
`../aros-crosstools`. They select Homebrew GNU make and a sibling `build-venv`
when available. Install the build prerequisites once:

```sh
brew install make llvm lld cmake zstd gawk automake autoconf bison flex netpbm libpng gnu-sed
python3 -m venv ../build-venv
../build-venv/bin/python -m pip install mako pyyaml
```

The OS build must use the patched AROS compiler below.
Existing user files and settings stay in `~/AROS/Shared` and
`~/Library/Application Support/AROS`; rebranding does not move or remove them.

After prerequisites and the preserved toolchain are available, run
`make pomaros-hosted`. It configures once, rebuilds the hosted OS with the
existing module scripts, builds the host bridges, and creates `build/PomAROS.app`.
Use `make pomaros-hosted-check` for bridge and packaging checks. This development
app uses the external stable OS tree; self-contained release images use
`graft/make-aros-release.sh` after the release checks.

---

## 3. The toolchain — you do not install it, the build produces it

There is **nothing to download and install** as a compiler. When you configure
AROS with `--with-toolchain=llvm`, the build compiles its own patched
cross-compiler from the official LLVM release tarballs:

- **Compiler:** clang/LLVM **20.1.0**, target `aarch64-unknown-aros`
- Version pinned in the OS source at `config/llvm_def`
- Fetched from `llvm-project` release `llvmorg-20.1.0`
- Linker is LLVM `ld.lld`; the binutils are the `llvm-*` tools

Two rules that will cost you a day each if you skip them:

- **Do not substitute your system clang.** A plain Homebrew/distro clang is not
  the AROS-patched one and dies at `-noposixc`. Let the build produce clang 20.1.0.
- **Keep it exactly at 20.1.0.** If you ever patch the toolchain's freestanding
  headers from a newer clang, `va_start` compiles as a call to a builtin that
  does not exist. It is a *warning, not an error*, so the build succeeds and all
  varargs silently break at runtime with no useful crash.

Building the toolchain from source is a **one-time ~1–2 hour** step. After that
the `crosstools` directory is relocatable — copy it aside and reuse it, and you
never pay that cost again (see step 4).

## 4. Build hosted AROS

Read [docs/features/build/README.md](docs/features/build/README.md) for the
module list and failure diagnosis. For an existing preserved AROS compiler:

```sh
make pomaros-hosted
```

The script configures the isolated stable `../Build/pomaros-hosted` directory
once and then invokes the existing module rebuild recipe. It reuses
`../aros-crosstools` and never deletes a configured tree. Override `AROS_SRC`,
`BUILD`/`AROS_BUILD`, or `XT`/`AROS_CROSSTOOLS` when using another layout; the aliases are accepted by both build scripts.

If there is no preserved compiler, build it once in a separate stable tree:

```sh
AROS_SRC=$(cd ../aros-core-pomaros && pwd)
. ../build-venv/bin/activate
BUILD=$(pwd)/../Build/pomaros-toolchain
mkdir -p "$BUILD"
cd "$BUILD"
export PATH="/opt/homebrew/opt/make/libexec/gnubin:/opt/homebrew/bin:$PATH"
"$AROS_SRC/configure" --target=darwin-aarch64 --with-toolchain=llvm --without-x
make crosstools-toolchain
cp -a bin/darwin-aarch64/tools/crosstools ../../aros-crosstools
```

Return to `pomaros-hosted`, activate the `build-venv` created above, and run the
product build. The first toolchain build is deliberately separate from routine
product rebuilds so a missing compiler cannot silently trigger hours of work.

---

## 5. Build the host shims and run it

The Mac-side host capabilities (display, clipboard, audio, sockets) are dylibs
built from *this* repo:

```sh
cd path/to/pomaros-hosted
make cocoametal-dylib pasteboard-dylib coreaudio-dylib bsdsock-dylib   # -> build/*.dylib
```

Then deploy and boot a live Cocoa/Metal window:

```sh
./graft/aros-ctl deploy                              # stage dylibs + the Cocoa monitor into the boot tree
./graft/deploy-check                                 # sanity-check every runnable copy is fresh
AROS_CTL_STARTUP_MODE=desktop ./graft/run-window.sh  # boot AROS to the Workbench desktop
```

A window titled "PomAROS" opens. Click it for keyboard focus and type at the shell.
`run-window.sh` with no env var boots to a CLI; `desktop` mode boots Wanderer.

Package it as a double-clickable app:

```sh
./graft/make-aros-app.sh                              # -> build/PomAROS.app
```

Or drive it **headlessly** (no window-server session, no Screen-Recording
prompt) — this is how the project verifies itself unattended:

```sh
./graft/aros-ctl run                                 # boot, then type/click/screenshot from the CLI
```

If a change you made "doesn't take," it is almost always a stale copy — this port
has several runnable copies of the same artifacts. Read
[docs/features/deployment/README.md](docs/features/deployment/README.md).

---

## 6. Where to go next

| You want to… | Read |
|---|---|
| The big picture and current documentation map | [README.md](README.md) · [docs/README.md](docs/README.md) |
| Architecture decisions and the bug log | [Decision log](docs/history/DECISION-LOG.md) |
| Build details, traps, symptom→cause table | [docs/features/build/README.md](docs/features/build/README.md) |
| Deploy/run and the "several copies" trap | [docs/features/deployment/README.md](docs/features/deployment/README.md) |
| Drive/verify AROS headlessly | [docs/features/control-harness/README.md](docs/features/control-harness/README.md) |
| The full host-feature set (built + planned) | [docs/features/README.md](docs/features/README.md) |
| How the two repos relate + the active graft tools | [docs/project/REPOSITORY-STRATEGY.md](docs/project/REPOSITORY-STRATEGY.md) · [graft/README.md](graft/README.md) |
| How the original AArch64 and hosted ports were started | [docs/hosted/initial-platform-bringup/](docs/hosted/initial-platform-bringup/README.md) |

Welcome aboard.
