# t2-build

[![Code of Conduct](https://img.shields.io/badge/%E2%9D%A4-code%20of%20conduct-blue.svg?style=flat)](https://github.com/tessel/project/blob/master/CONDUCT.md)

Build tooling for the Tessel 2 OpenWrt image. Works on **Windows, Linux, and macOS** via Docker.

---

## Quick start (Windows, Linux, or macOS)

**Requirements:** [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Windows/macOS) or Docker Engine (Linux).

```powershell
# PowerShell (Windows) or bash (Linux/macOS/WSL)
git clone https://github.com/aaronpowell/t2-build.git
cd t2-build
docker compose run --rm build
```

That's it. On first run the container:
1. Clones the forked `openwrt` and `openwrt-tessel` repos into a Docker-managed Linux volume
2. Builds the fragile legacy host tools (scons, cmake, mkimage) against Ubuntu 18.04 userspace
3. Runs the full OpenWrt world build
4. Copies the output `.bin` files to `./output/` where your host OS can read them

Subsequent runs skip cloning and reuse the build cache — much faster.

**Output files in `./output/`:**
```
openwrt-ramips-mt7620-tessel-squashfs-sysupgrade.bin   (~4.3 MB, flash this to the board)
openwrt-ramips-mt7620-uImage.bin
```

---

## Why Docker?

The Tessel 2 OpenWrt image is built from a ~2014-era toolchain that collides with modern hosts:
- requires Python 2
- old CMake sources break against modern libstdc++
- mkimage requires pre-OpenSSL-3 APIs

Rather than patching every host tool, the build runs inside Ubuntu 18.04 which has the right environment natively. The source tree lives in a **Docker named volume** (a Linux filesystem), which also avoids Windows NTFS limitations (colon characters in filenames, case sensitivity).

---

## Docker Compose commands

```powershell
# Full build (clone + host-tools + world) — recommended
docker compose run --rm build

# Open a shell inside the build container (for debugging)
docker compose run --rm shell

# Step-by-step (advanced)
docker compose run --rm build clone       # clone sources only
docker compose run --rm build host-tools  # build legacy host tools only
docker compose run --rm build world       # run make world + copy artifacts
```

---

## Using your own forks

Set environment variables to point at different upstream repos:

```powershell
# PowerShell
$env:OPENWRT_FORK="https://github.com/yourusername/openwrt.git"
$env:OPENWRT_BRANCH="2018-07-13"
$env:OPENWRT_TESSEL_FORK="https://github.com/yourusername/openwrt-tessel.git"
docker compose run --rm build
```

```bash
# bash
OPENWRT_FORK=https://github.com/yourusername/openwrt.git \
OPENWRT_TESSEL_FORK=https://github.com/yourusername/openwrt-tessel.git \
docker compose run --rm build
```

---

## Resetting the build cache

The source tree and build artifacts live in a Docker named volume (`t2-build_openwrt-src`). To start fresh:

```powershell
docker compose down -v   # removes the volume
docker compose run --rm build
```

---

## Controlling parallelism

```powershell
$env:BUILD_JOBS=4
docker compose run --rm build
```

Defaults to all available CPU cores.

---

## Linux/WSL direct build (alternative)

If you prefer to run the build directly in Linux without Docker Compose, `openwrt-env.sh` is still available:

```bash
./openwrt-env.sh build-image
./openwrt-env.sh host-tools
./openwrt-env.sh world
```

This variant mounts the sibling workspace (expects `openwrt/` and `openwrt-tessel/` next to `t2-build/`).

---

## Why Ubuntu 18.04?

Ubuntu 18.04 is the oldest base image that still bootstraps cleanly from today's package mirrors while preserving Python 2 and avoiding the OpenSSL 3 / libstdc++ breakage introduced in Ubuntu 22.04+. Ubuntu 16.04 was tried and got further than 24.04 in early experiments, which confirmed the older-userspace strategy is correct.

## Historical Vagrant flow

**NOTE:** You will need to have `ansible` installed before running.

```
vagrant up
vagrant ssh
$ cd /work
$ git clone --recursive https://github.com/tessel/openwrt-tessel.git
$ cd openwrt-tessel
$ make -j64; make -j64; make -j64 V=s
$ cd /work
$ git clone https://github.com/tessel/t2-firmware --recursive
$ cd t2-firmware
$ make -j64
```

To generate `toolchain-mipsel.tar.gz` for `t2-compiler`, run:

```
tar -cvzf /work/toolchain-mipsel.tar.gz \
  -C /work/openwrt-tessel/openwrt/staging_dir/ \
  target-mipsel_24kec+dsp_uClibc-0.9.33.2 \
  toolchain-mipsel_24kec+dsp_gcc-4.8-linaro_uClibc-0.9.33.2
```

...and upload the resulting `/work/toolchain-mipsel.tar.gz` file.

# License

MIT or Apache2-.0, at your option.
