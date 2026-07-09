# t2-build

[![Code of Conduct](https://img.shields.io/badge/%E2%9D%A4-code%20of%20conduct-blue.svg?style=flat)](https://github.com/tessel/project/blob/master/CONDUCT.md)

Legacy Ansible and Vagrant scripts for building t2.

## Preferred OpenWrt build environment for the revival effort

The original Vagrant flow targeted Ubuntu 14.04. That still reflects the era of the toolchain, but on a modern 2026 host the most practical option is to keep the host modern and run the OpenWrt build inside an older container userspace.

`openwrt-env.sh` builds and runs an Ubuntu 18.04 image that keeps the old host-tool expectations together:

- `scons` still has Python 2 available as `/usr/bin/python`
- the bundled OpenWrt `cmake-2.8.12.2` sees an older libstdc++/glibc combination
- `mkimage` builds against a pre-OpenSSL-3 userspace

This avoids having to patch every historical host utility just to survive on Ubuntu 24.04+.

### Requirements

- Docker or Podman
- a workspace layout where `openwrt-tessel/` and `openwrt/` are both present under the same parent directory (the current revival workspace already looks like this)

### Quick start

From this repository:

```bash
./openwrt-env.sh build-image
./openwrt-env.sh host-tools
./openwrt-env.sh world
```

Useful commands:

```bash
./openwrt-env.sh shell
./openwrt-env.sh fix-perms
./openwrt-env.sh exec 'make -j"$(nproc)" download'
```

`host-tools` is the fast smoke test for the historically fragile bits (`scons`, old `cmake`, and `mkimage`).

`world` runs the traditional retry pattern:

```bash
make -j"$(nproc)" || make -j"$(nproc)" || make -j1 V=s
```

The script mounts the whole sibling workspace into the container so the `openwrt-tessel/openwrt -> ../openwrt` link works unchanged.

If earlier experiments left root-owned files in `openwrt/tmp`, `build_dir`, or `staging_dir`, run `./openwrt-env.sh fix-perms` once before rebuilding.

### Why Ubuntu 18.04 instead of patching the host?

On current hosts we already know the legacy OpenWrt tree collides with:

- Python 2 removal
- old CMake sources vs modern libstdc++
- old U-Boot host tools vs OpenSSL 3 APIs

Ubuntu 16.04 got further in local experiments, which confirmed that an older userspace is the right strategy. In practice, Ubuntu 18.04 is the oldest base image that still bootstraps cleanly from today's public package mirrors, while still preserving Python 2 and avoiding the OpenSSL 3 / newest-libstdc++ breakage from Ubuntu 24.04.

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
