#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/dockkey-tests.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT
xcrun swiftc -module-cache-path "${TMPDIR:-/tmp}/dockkey-module-cache" Source/Dock.swift Tests/main.swift -o "$TEST_DIR/tests"
"$TEST_DIR/tests"
