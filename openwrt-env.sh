#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
OPENWRT_TESSEL_DIR="${OPENWRT_TESSEL_DIR:-${WORKSPACE_ROOT}/openwrt-tessel}"
IMAGE_NAME="${IMAGE_NAME:-tessel-openwrt-bionic}"
CONTAINER_HOME="${SCRIPT_DIR}/.container-home"
DOCKERFILE="${SCRIPT_DIR}/docker/openwrt-bionic/Dockerfile"

if command -v docker >/dev/null 2>&1; then
  CONTAINER_ENGINE="${CONTAINER_ENGINE:-docker}"
elif command -v podman >/dev/null 2>&1; then
  CONTAINER_ENGINE="${CONTAINER_ENGINE:-podman}"
else
  echo "error: docker or podman is required" >&2
  exit 1
fi

usage() {
  cat <<'EOF'
Usage: ./openwrt-env.sh <command>

Commands:
  build-image   Build the Ubuntu 18.04 OpenWrt container image
  shell         Open an interactive shell in the container
  exec <cmd>    Run an arbitrary command in the container
  fix-perms     Chown common OpenWrt build artifacts back to the host user
  host-tools    Rebuild the fragile host tools (scons, cmake, mkimage)
  download      Run the OpenWrt download step
  world         Run the full OpenWrt world build with retries
EOF
}

ensure_workspace() {
  if [[ ! -d "${OPENWRT_TESSEL_DIR}" ]]; then
    echo "error: expected ${OPENWRT_TESSEL_DIR} to exist" >&2
    echo "hint: set WORKSPACE_ROOT=/path/to/workspace if your layout differs" >&2
    exit 1
  fi
}

build_image() {
  "${CONTAINER_ENGINE}" build \
    --tag "${IMAGE_NAME}" \
    --file "${DOCKERFILE}" \
    "${SCRIPT_DIR}"
}

run_in_container() {
  local command="$1"
  local tty_flags=(-i)

  mkdir -p "${CONTAINER_HOME}"

  if [[ -t 0 && -t 1 ]]; then
    tty_flags=(-it)
  fi

  "${CONTAINER_ENGINE}" run --rm "${tty_flags[@]}" \
    --user "$(id -u):$(id -g)" \
    --env HOME=/work/t2-build/.container-home \
    --env FORCE_UNSAFE_CONFIGURE=1 \
    --volume "${WORKSPACE_ROOT}:/work" \
    --workdir /work/openwrt-tessel \
    "${IMAGE_NAME}" \
    bash -lc "${command}"
}

fix_permissions() {
  "${CONTAINER_ENGINE}" run --rm \
    --user 0:0 \
    --volume "${WORKSPACE_ROOT}:/work" \
    "${IMAGE_NAME}" \
    bash -lc "chown -R $(id -u):$(id -g) /work/openwrt /work/openwrt-tessel /work/t2-build"
}

ensure_workspace

case "${1:-}" in
  build-image)
    build_image
    ;;
  shell)
    build_image
    run_in_container "bash"
    ;;
  exec)
    shift
    if [[ $# -eq 0 ]]; then
      echo "error: exec requires a command" >&2
      usage
      exit 1
    fi
    build_image
    run_in_container "$*"
    ;;
  fix-perms)
    build_image
    fix_permissions
    ;;
  host-tools)
    build_image
    run_in_container "make -C openwrt tools/scons/clean tools/cmake/clean tools/mkimage/clean && make -C openwrt tools/scons/install tools/cmake/install tools/mkimage/install V=s"
    ;;
  download)
    build_image
    run_in_container "make download"
    ;;
  world)
    build_image
    run_in_container "make -j\"$(nproc)\" || make -j\"$(nproc)\" || make -j1 V=s"
    ;;
  *)
    usage
    exit 1
    ;;
esac
