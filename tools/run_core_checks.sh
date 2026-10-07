#!/bin/sh
# Compiles the app logic (Lexicometre/Model) with a test harness and runs it.
# Works on macOS (Xcode command line tools) and Linux (Swift 5.10+).
set -e
cd "$(dirname "$0")/.."
OUT="${TMPDIR:-/tmp}/lexicometre-core-checks"
swiftc -O -swift-version 5 Lexicometre/Model/*.swift tools/CoreChecks/main.swift -o "$OUT"
"$OUT" Lexicometre/Resources/mots.tsv
