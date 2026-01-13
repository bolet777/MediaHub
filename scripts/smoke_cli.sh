#!/usr/bin/env bash
set -euo pipefail

# MediaHub CLI Smoke Test
# - Uses ONLY /tmp paths
# - SAFE: no touching any real libraries

BIN="swift run mediahub"

LIB="/tmp/mh_library"
LIB_MOVED="/tmp/mh_library_moved"
SRC="/tmp/mh_source"

# --- helpers ---
fail() { echo "ERROR: $*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"; }

need_cmd swift
need_cmd python3

run() {
  echo "+ $BIN $*" >&2
  $BIN "$@"
}

# Extract JSON from command output (handles build messages)
extract_json() {
  local output="$1"
  # Try to find JSON object in output (look for { ... })
  python3 -c "
import json, sys, re
text = sys.argv[1]
# Remove build messages (lines starting with [ or containing 'Building' or 'Planning')
lines = [l for l in text.split('\n') if l and not l.strip().startswith('[') and 'Building' not in l and 'Planning' not in l and 'Compiling' not in l and 'Write swift-version' not in l]
cleaned = '\n'.join(lines)
# Try to find JSON object boundaries
match = re.search(r'\{.*\}', cleaned, re.DOTALL)
if match:
    try:
        j = json.loads(match.group(0))
        print(json.dumps(j))
    except:
        pass
" "$output"
}

assert_eq() {
  local got="$1" expected="$2" msg="$3"
  [[ "$got" == "$expected" ]] || fail "$msg (got='$got', expected='$expected')"
}

assert_file_exists() {
  local path="$1"
  [[ -f "$path" ]] || fail "Expected file to exist: $path"
}

assert_dir_exists() {
  local path="$1"
  [[ -d "$path" ]] || fail "Expected directory to exist: $path"
}

# --- setup ---
echo "== Clean tmp =="
rm -rf "$LIB" "$LIB_MOVED" "$SRC"
mkdir -p "$SRC/sub"

echo "== Create fake media =="
printf "fake" > "$SRC/IMG_0001.HEIC"
printf "fake" > "$SRC/IMG_0002.JPG"
printf "fake" > "$SRC/sub/VID_0003.MOV"
printf "fake" > "$SRC/sub/IMG_0004.PNG"

# Set deterministic mtimes (2024-01 through 2024-04)
touch -t 202401021200 "$SRC/IMG_0001.HEIC"
touch -t 202402031200 "$SRC/IMG_0002.JPG"
touch -t 202403041200 "$SRC/sub/VID_0003.MOV"
touch -t 202404051200 "$SRC/sub/IMG_0004.PNG"

# --- create library ---
echo "== Create library (positional path) =="
run library create "$LIB"

assert_dir_exists "$LIB/.mediahub"
assert_file_exists "$LIB/.mediahub/library.json"

# Set library context for subsequent commands
export MEDIAHUB_LIBRARY="$LIB"

# --- attach source ---
echo "== Attach source =="
ATTACH_JSON=$(run source attach "$SRC" --json)
SID=$(python3 -c "import json, sys; j=json.loads(sys.argv[1]); print(j.get('sourceId', j.get('source_id', j.get('id', ''))))" "$ATTACH_JSON")
[[ -n "$SID" ]] || fail "sourceId missing from attach output"
echo "Source ID: $SID"

# --- detect (first run) ---
echo "== Detect (should find 4 new) =="
DETECT1_JSON=$(run detect "$SID" --json)
TOTAL1=$(python3 -c "import json, sys; j=json.loads(sys.argv[1]); print(j['summary']['totalScanned'])" "$DETECT1_JSON")
NEW1=$(python3 -c "import json, sys; j=json.loads(sys.argv[1]); print(j['summary']['newItems'])" "$DETECT1_JSON")
assert_eq "$TOTAL1" "4" "detect totalScanned mismatch"
assert_eq "$NEW1" "4" "detect newItems mismatch"

# --- import all ---
echo "== Import --all (should import 4) =="
IMPORT1_JSON=$(run import "$SID" --all --json)
IMPORTED1=$(python3 -c "import json, sys; j=json.loads(sys.argv[1]); print(j['summary']['imported'])" "$IMPORT1_JSON")
FAILED1=$(python3 -c "import json, sys; j=json.loads(sys.argv[1]); print(j['summary']['failed'])" "$IMPORT1_JSON")
assert_eq "$IMPORTED1" "4" "import imported count mismatch"
assert_eq "$FAILED1" "0" "import failed count mismatch"

# Verify imported files exist under /tmp/mh_library/2024/<MM>/...
echo "== Verify imported files =="
assert_file_exists "$LIB/2024/01/IMG_0001.HEIC"
assert_file_exists "$LIB/2024/02/IMG_0002.JPG"
assert_file_exists "$LIB/2024/03/VID_0003.MOV"
assert_file_exists "$LIB/2024/04/IMG_0004.PNG"

# --- detect after import ---
echo "== Detect after import (should find 0 new, 4 known) =="
DETECT2_JSON=$(run detect "$SID" --json)
NEW2=$(python3 -c "import json, sys; j=json.loads(sys.argv[1]); print(j['summary']['newItems'])" "$DETECT2_JSON")
KNOWN2=$(python3 -c "import json, sys; j=json.loads(sys.argv[1]); print(j['summary']['knownItems'])" "$DETECT2_JSON")
assert_eq "$NEW2" "0" "detect newItems should be 0 after import"
assert_eq "$KNOWN2" "4" "detect knownItems should be 4 after import"

# --- idempotence: import again should import 0 ---
echo "== Import again (idempotence) =="
IMPORT2_JSON=$(run import "$SID" --all --json)
# Handle case where no new items returns {"message": "..."} instead of full ImportResult
IMPORTED2=$(python3 -c "import json, sys; j=json.loads(sys.argv[1]); print(j.get('summary', {}).get('imported', 0) if 'summary' in j else 0)" "$IMPORT2_JSON")
assert_eq "$IMPORTED2" "0" "idempotent import should import 0 items"

# --- move library test ---
echo "== Move library folder test =="
rm -rf "$LIB_MOVED"
mv "$LIB" "$LIB_MOVED"
export MEDIAHUB_LIBRARY="$LIB_MOVED"

# Get original libraryId from library.json
ORIG_LIB_ID=$(python3 -c "import json; j=json.load(open('$LIB_MOVED/.mediahub/library.json')); print(j['libraryId'])" 2>/dev/null || echo "")

# status should work and libraryId should be unchanged
# Note: status JSON uses 'identifier' key, not 'libraryId'
STATUS_MOVED_OUTPUT=$(run status --json 2>&1)
STATUS_MOVED_JSON=$(extract_json "$STATUS_MOVED_OUTPUT")
if [[ -z "$STATUS_MOVED_JSON" ]]; then
  echo "DEBUG: status output was: $STATUS_MOVED_OUTPUT" >&2
  fail "status command returned no valid JSON"
fi
STATUS_MOVED_ID=$(python3 -c "import json, sys; j=json.loads(sys.argv[1]); print(j.get('identifier', ''))" "$STATUS_MOVED_JSON" 2>/dev/null || echo "")
if [[ -z "$STATUS_MOVED_ID" ]]; then
  echo "DEBUG: extracted JSON was: $STATUS_MOVED_JSON" >&2
  fail "Could not extract identifier from status JSON"
fi
if [[ -n "$ORIG_LIB_ID" ]]; then
  assert_eq "$STATUS_MOVED_ID" "$ORIG_LIB_ID" "libraryId changed after move"
fi

echo "== Final library file tree =="
find "$LIB_MOVED" -maxdepth 3 -type f | sed "s|$LIB_MOVED/||" | sort

echo "== DONE: Smoke test passed =="
