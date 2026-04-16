#!/usr/bin/env bash
# Push the LiteRT-LM bundle to the phone over USB (adb).
#
# Default destination is the app-specific external files dir (Android 13+ friendly):
#   /storage/emulated/0/Android/data/<applicationId>/files/gemma-4-E2B-it.litertlm
# GyaanAi [ModelManager] checks this path via path_provider getExternalStorageDirectory().
# Public Download/ is still scanned but is often invisible to the app on modern Android
# without runtime / all-files access — use this script path instead.
#
# Usage:
#   ./scripts/push_offline_model_to_android.sh
#   ./scripts/push_offline_model_to_android.sh /path/to/gemma-4-E2B-it.litertlm
#   ./scripts/push_offline_model_to_android.sh -s DEVICE_SERIAL
#   ./scripts/push_offline_model_to_android.sh -s DEVICE_SERIAL /path/to/model
# Or: export ANDROID_SERIAL=AUYFVB5B18003024   # same as flutter "mobile" id
#
# Prereqs: USB debugging on, phone unlocked, `adb devices` shows the device.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DEFAULT_SRC="$REPO_ROOT/../gyaanai_backend/gemma-4-E2B-it.litertlm"

while [[ $# -gt 0 && "$1" == "-s" ]]; do
  if [[ -z "${2:-}" ]]; then
    echo "usage: $0 [-s ANDROID_SERIAL] [path-to-gemma-4-E2B-it.litertlm]" >&2
    exit 1
  fi
  export ANDROID_SERIAL="$2"
  shift 2
done

if [[ $# -gt 1 ]]; then
  echo "Too many arguments (use: [-s SERIAL] [optional-model-path])" >&2
  exit 1
fi

SRC="${1:-$DEFAULT_SRC}"

MODEL_NAME="gemma-4-E2B-it.litertlm"
# Must match android/app/build.gradle.kts defaultConfig.applicationId
ANDROID_PKG="com.example.gyaanai"
DEST_DIR="/storage/emulated/0/Android/data/${ANDROID_PKG}/files"
DEST="${DEST_DIR}/${MODEL_NAME}"

if [[ ! -f "$SRC" ]]; then
  echo "Model file not found: $SRC" >&2
  echo "Pass the path as the first argument, or place the file at:" >&2
  echo "  $DEFAULT_SRC" >&2
  exit 1
fi

if ! command -v adb >/dev/null 2>&1; then
  echo "adb not found. Install Android platform-tools and ensure adb is on PATH." >&2
  exit 1
fi

echo "Source (Mac, unchanged): $SRC ($(du -h "$SRC" | cut -f1))"
echo "Destination (phone only): $DEST"
echo "adb push copies Mac → phone; it does not replace your Mac file."
if [[ -n "${ANDROID_SERIAL:-}" ]]; then
  echo "Targeting adb device: $ANDROID_SERIAL (from -s or ANDROID_SERIAL env)"
fi
adb devices

echo "Creating destination dir on device..."
if ! adb shell "mkdir -p '$DEST_DIR'"; then
  echo "mkdir failed. Install and open GyaanAi once (so Android creates Android/data/${ANDROID_PKG}/), then run this script again." >&2
  exit 1
fi

# macOS BSD stat
LOCAL_BYTES="$(stat -f%z "$SRC" 2>/dev/null || wc -c <"$SRC" | tr -d ' ')"
echo "Local size: $LOCAL_BYTES bytes"

if ! adb push "$SRC" "$DEST"; then
  echo "adb push failed (exit non-zero). Check cable, USB mode, and storage space on the phone." >&2
  exit 1
fi

# Size on device (strip CR from adb shell on Windows-style line endings)
REMOTE_BYTES="$(adb shell "wc -c '$DEST'" 2>/dev/null | awk '{print $1}' | tr -d '\r' || true)"
if [[ -z "$REMOTE_BYTES" || ! "$REMOTE_BYTES" =~ ^[0-9]+$ ]]; then
  echo "Could not read remote file size. Check manually: adb shell ls -lh '$DEST'" >&2
  exit 1
fi

echo "Phone file size: $REMOTE_BYTES bytes"
if [[ "$REMOTE_BYTES" -ne "$LOCAL_BYTES" ]]; then
  echo "ERROR: Phone file size does not match Mac (transfer incomplete or wrong path)." >&2
  echo "Remove the partial file and retry: adb shell rm -f \"$DEST\"" >&2
  exit 1
fi

echo "OK — full model is on the phone at $DEST"
echo "Force-quit GyaanAi and reopen so it rescans for the model."
