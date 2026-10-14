#!/usr/bin/env bash
# Cloud Agent install for Medication Tracker.
#
# This is an iOS app (SwiftUI + SwiftData). Building and running the full app,
# the UI tests, and the SwiftData-backed unit tests require macOS + Xcode + an
# iOS Simulator, which Cloud Agent (Linux) VMs cannot provide.
#
# What this script CAN set up on Linux is the open-source Swift toolchain, which
# lets agents edit, type-check, and run the platform-independent Swift logic
# (schedule/duration math, formatting, domain enums, brand-name lookup, etc.).
#
# The script is idempotent: it is safe to run repeatedly and against a snapshot
# that already contains the toolchain.
set -euo pipefail

SWIFT_VERSION="6.1.2"
SWIFT_HOME="/opt/swift"
SWIFT_BIN="${SWIFT_HOME}/usr/bin/swift"
UBUNTU_SLUG="ubuntu24.04"

echo "==> Ensuring Swift Linux system dependencies are present"
if ! dpkg -s libpython3-dev >/dev/null 2>&1; then
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    binutils git gnupg2 libc6-dev libcurl4-openssl-dev libedit2 libgcc-13-dev \
    libncurses-dev libpython3-dev libsqlite3-0 libstdc++-13-dev libxml2-dev \
    libz3-dev pkg-config tzdata unzip zlib1g-dev
else
  echo "    dependencies already installed"
fi

echo "==> Ensuring Swift ${SWIFT_VERSION} toolchain is installed at ${SWIFT_HOME}"
if [ -x "${SWIFT_BIN}" ] && "${SWIFT_BIN}" --version 2>/dev/null | grep -q "swift-${SWIFT_VERSION}"; then
  echo "    Swift ${SWIFT_VERSION} already present"
else
  tarball="swift-${SWIFT_VERSION}-RELEASE-${UBUNTU_SLUG}.tar.gz"
  url="https://download.swift.org/swift-${SWIFT_VERSION}-release/${UBUNTU_SLUG//./}/swift-${SWIFT_VERSION}-RELEASE/${tarball}"
  tmp="$(mktemp -d)"
  echo "    downloading ${url}"
  curl -fSL --retry 4 --retry-delay 4 -o "${tmp}/${tarball}" "${url}"
  sudo rm -rf "${SWIFT_HOME}"
  sudo mkdir -p "${SWIFT_HOME}"
  sudo tar -xzf "${tmp}/${tarball}" -C "${SWIFT_HOME}" --strip-components=1
  rm -rf "${tmp}"
fi

echo "==> Exposing swift/swiftc on PATH"
sudo ln -sf "${SWIFT_HOME}/usr/bin/swift" /usr/local/bin/swift
sudo ln -sf "${SWIFT_HOME}/usr/bin/swiftc" /usr/local/bin/swiftc

echo "==> Swift toolchain ready:"
swift --version
