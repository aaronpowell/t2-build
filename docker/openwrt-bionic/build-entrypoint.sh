#!/usr/bin/env bash
# build-entrypoint.sh — runs inside the Ubuntu 18.04 build container
#
# On first run it clones the source repos into the Docker volume.
# On subsequent runs it skips cloning and goes straight to the build step.
# Artifacts are copied to /artifacts (bind-mounted to ./output on the host).

set -euo pipefail

OPENWRT_FORK="${OPENWRT_FORK:-https://github.com/aaronpowell/openwrt.git}"
OPENWRT_BRANCH="${OPENWRT_BRANCH:-2018-07-13}"
OPENWRT_TESSEL_FORK="${OPENWRT_TESSEL_FORK:-https://github.com/aaronpowell/openwrt-tessel.git}"
BUILD_JOBS="${BUILD_JOBS:-$(nproc)}"

WORK=/work

clone_sources() {
  echo "==> Cloning openwrt-tessel ..."
  git clone --depth=1 "$OPENWRT_TESSEL_FORK" "$WORK/openwrt-tessel"

  echo "==> Cloning openwrt ($OPENWRT_BRANCH) ..."
  git clone --depth=1 --branch "$OPENWRT_BRANCH" "$OPENWRT_FORK" "$WORK/openwrt"

  echo "==> Linking openwrt into openwrt-tessel ..."
  # openwrt-tessel expects openwrt/ as a subdirectory
  ln -sf ../openwrt "$WORK/openwrt-tessel/openwrt"

  echo "==> Copying feeds.conf and config ..."
  cp "$WORK/openwrt-tessel/feeds.conf" "$WORK/openwrt/feeds.conf" 2>/dev/null || true

  echo "==> Updating feeds ..."
  cd "$WORK/openwrt"
  ./scripts/feeds update -a
  ./scripts/feeds install -a
}

apply_config() {
  echo "==> Applying Tessel config ..."
  cd "$WORK/openwrt-tessel"
  make -C "$WORK/openwrt" defconfig KCONFIG_ALLCONFIG="$WORK/openwrt-tessel/config.mk" 2>/dev/null || \
    make -C "$WORK/openwrt" defconfig
}

build_host_tools() {
  echo "==> Building host tools ..."
  cd "$WORK/openwrt"
  make tools/scons/clean  tools/cmake/clean  tools/mkimage/clean  2>/dev/null || true
  make tools/scons/install tools/cmake/install tools/mkimage/install V=s
}

build_world() {
  echo "==> Building world (jobs=$BUILD_JOBS) ..."
  cd "$WORK/openwrt"
  make -j"$BUILD_JOBS" || make -j"$BUILD_JOBS" || make -j1 V=s
}

copy_artifacts() {
  echo "==> Copying artifacts to /artifacts ..."
  mkdir -p /artifacts
  find "$WORK/openwrt/bin/ramips" -name "*.bin" -exec cp {} /artifacts/ \; 2>/dev/null || true
  echo "==> Done. Contents of /artifacts:"
  ls -lh /artifacts/
}

# ---- main ----

case "${1:-build}" in
  build)
    if [[ ! -d "$WORK/openwrt-tessel/.git" ]]; then
      clone_sources
      apply_config
      build_host_tools
    fi
    build_world
    copy_artifacts
    ;;
  clone)
    clone_sources
    apply_config
    ;;
  host-tools)
    build_host_tools
    ;;
  world)
    build_world
    copy_artifacts
    ;;
  shell)
    exec bash
    ;;
  *)
    echo "usage: build-entrypoint.sh [build|clone|host-tools|world|shell]"
    exit 1
    ;;
esac
