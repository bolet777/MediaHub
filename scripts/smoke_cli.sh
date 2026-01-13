#!/usr/bin/env bash
set -euo pipefail

# MediaHub CLI Smoke Test
# - Uses ONLY /tmp paths by default
# - SAFE: no touching any real libraries
# - Optional real-source tests (read-only) with -real flag

BIN="swift run mediahub"

# --- parse arguments ---
VERBOSE=0
REAL_SOURCES=0

show_help() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  -verbose, --verbose    Enable verbose output"
  echo "  -real, --real          Test with real sources (read-only)"
  echo "  -h, --help             Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0                     Run basic smoke test"
  echo "  $0 -verbose            Run with detailed output"
  echo "  $0 -real               Test with real sources"
  echo "  $0 -verbose -real      Verbose output with real sources"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -verbose|--verbose)
      VERBOSE=1
      shift
      ;;
    -real|--real)
      REAL_SOURCES=1
      shift
      ;;
    -h|--help)
      show_help
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Use -h or --help for usage information" >&2
      exit 1
      ;;
  esac
done

LIB="/tmp/mh_library"
LIB_MOVED="/tmp/mh_library_moved"
SRC="/tmp/mh_source"
LIB_REAL="/tmp/mh_library_real_sources"

# Real source paths (READ ONLY - never import into these)
REAL_SOURCE_PATHS=(
  "/Volumes/Photos/Photos/Librairie"
  "/Volumes/Photos/Photos/Librairie_Amateur"
  "/Volumes/Photos/Boulots"
  "/Volumes/Photos/Videos"
)

# --- colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# --- step tracking ---
STEP_NAMES=()
STEP_STATUSES=()
STEP_OUTPUTS=()
STEP_DURATIONS=()
STEP_ERRORS=()
SCRIPT_START_TIME=$(date +%s.%N)

# VERBOSE and REAL_SOURCES are set by argument parsing above

# Record a step result
record_step() {
  local name="$1"
  local status="$2"  # "PASS" or "FAIL"
  local output="$3"
  local duration="$4"
  local error="${5:-}"
  
  STEP_NAMES+=("$name")
  STEP_STATUSES+=("$status")
  STEP_OUTPUTS+=("$output")
  STEP_DURATIONS+=("$duration")
  STEP_ERRORS+=("$error")
}

# Get current time in seconds (with decimals)
step_start() {
  date +%s.%N
}

# Calculate duration between two timestamps
step_end() {
  local start="$1"
  local end=$(date +%s.%N)
  echo "$end" "$start" | awk '{printf "%.1f", $1 - $2}'
}

# Render final summary table
render_summary_table() {
  local total_duration=$(echo "$SCRIPT_START_TIME" "$(date +%s.%N)" | awk '{printf "%.1f", $2 - $1}')
  local all_passed=true
  
  # Check if any step failed
  for status in "${STEP_STATUSES[@]}"; do
    if [[ "$status" == "FAIL" ]]; then
      all_passed=false
      break
    fi
  done
  
  echo ""
  echo -e "${BOLD}┌─────────────────────────────┬────────┬──────────────────────────────────────┐${NC}"
  echo -e "${BOLD}│ STEP                        │ STATUS │ KEY OUTPUT                          │${NC}"
  echo -e "${BOLD}├─────────────────────────────┼────────┼──────────────────────────────────────┤${NC}"
  
  for i in "${!STEP_NAMES[@]}"; do
    local name="${STEP_NAMES[$i]}"
    local status="${STEP_STATUSES[$i]}"
    local output="${STEP_OUTPUTS[$i]}"
    local duration="${STEP_DURATIONS[$i]}"
    local error="${STEP_ERRORS[$i]}"
    
    # Truncate name if too long
    local name_plain=$(echo -e "$name" | sed 's/\x1b\[[0-9;]*m//g')
    if [[ ${#name_plain} -gt 25 ]]; then
      name="${name_plain:0:22}..."
    fi
    
    # Format status
    local status_icon=""
    if [[ "$status" == "PASS" ]]; then
      status_icon="${GREEN}✅${NC}"
    else
      status_icon="${RED}❌${NC}"
      all_passed=false
    fi
    
    # Format output (use error if present, otherwise use output)
    local display_output="$output"
    if [[ -n "$error" ]]; then
      display_output="${RED}$error${NC}"
    fi
    
    # Truncate output if too long
    local output_plain=$(echo -e "$display_output" | sed 's/\x1b\[[0-9;]*m//g')
    if [[ ${#output_plain} -gt 36 ]]; then
      local output_prefix="${output_plain:0:33}"
      if [[ -n "$error" ]]; then
        display_output="${RED}${output_prefix}...${NC}"
      else
        display_output="${output_prefix}..."
      fi
    fi
    
    # Simple printf with fixed widths (no vertical borders at start/end of content)
    printf "${BOLD}│${NC} %-25s ${BOLD}│${NC} %-6s ${BOLD}│${NC} %-36s ${BOLD}│${NC}\n" "$name" "$status_icon" "$display_output"
  done
  
  echo -e "${BOLD}└─────────────────────────────┴────────┴──────────────────────────────────────┘${NC}"
  echo ""
  
  # Final status
  if [[ "$all_passed" == "true" ]]; then
    echo -e "${GREEN}${BOLD}FINAL: ✅ PASS${NC}   ${CYAN}Duration: ${total_duration}s${NC}"
  else
    echo -e "${RED}${BOLD}FINAL: ❌ FAIL${NC}   ${CYAN}Duration: ${total_duration}s${NC}"
  fi
  echo ""
}

# --- helpers ---
fail() { 
  echo -e "${RED}${BOLD}✗ ERREUR:${NC} ${RED}$*${NC}" >&2
  exit 1
}

success() {
  if [[ "$VERBOSE" == "1" ]]; then
    echo -e "${GREEN}${BOLD}✓${NC} ${GREEN}$*${NC}"
  fi
}

info() {
  if [[ "$VERBOSE" == "1" ]]; then
    echo -e "${CYAN}ℹ${NC} ${CYAN}$*${NC}"
  fi
}

step() {
  if [[ "$VERBOSE" == "1" ]]; then
    echo ""
    echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}${BOLD}  $*${NC}"
    echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  else
    echo -e "${BLUE}${BOLD}▶${NC} ${BLUE}$*${NC}..."
  fi
}

test_header() {
  if [[ "$VERBOSE" == "1" ]]; then
    echo ""
    echo -e "${MAGENTA}${BOLD}▶ Test:${NC} ${MAGENTA}$*${NC}"
  fi
}

need_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Commande requise manquante: $1"; }

need_cmd swift
need_cmd python3

# --- welcome ---
echo ""
echo -e "${BLUE}${BOLD}╔═══════════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}${BOLD}║                                                                                   ║${NC}"
echo -e "${BLUE}${BOLD}║                    ${CYAN}MediaHub CLI - Test de Fumée${BLUE}${BOLD}                          ║${NC}"
echo -e "${BLUE}${BOLD}║                                                                                   ║${NC}"
echo -e "${BLUE}${BOLD}║  ${NC}Ce script teste le workflow complet du CLI MediaHub:${BLUE}${BOLD}                        ║${NC}"
echo -e "${BLUE}${BOLD}║  ${NC}• Création de bibliothèque${BLUE}${BOLD}                                                      ║${NC}"
echo -e "${BLUE}${BOLD}║  ${NC}• Attachement de source${BLUE}${BOLD}                                                         ║${NC}"
echo -e "${BLUE}${BOLD}║  ${NC}• Détection et import de médias${BLUE}${BOLD}                                                 ║${NC}"
echo -e "${BLUE}${BOLD}║  ${NC}• Tests d'idempotence et de déplacement${BLUE}${BOLD}                                        ║${NC}"
echo -e "${BLUE}${BOLD}║                                                                                   ║${NC}"
if [[ "$REAL_SOURCES" == "1" ]]; then
  echo -e "${BLUE}${BOLD}║  ${RED}${BOLD}⚠ MODE SOURCES RÉELLES ACTIVÉ (-real)${BLUE}${BOLD}                              ║${NC}"
  echo -e "${BLUE}${BOLD}║  ${RED}${BOLD}  LECTURE SEULE - AUCUN IMPORT NE SERA EFFECTUÉ${BLUE}${BOLD}                                 ║${NC}"
else
  echo -e "${BLUE}${BOLD}║  ${YELLOW}⚠ Utilise uniquement des chemins /tmp - SÉCURISÉ${BLUE}${BOLD}                              ║${NC}"
  echo -e "${BLUE}${BOLD}║  ${CYAN}💡 Pour tester des sources réelles: $0 -real${BLUE}${BOLD}          ║${NC}"
fi
echo -e "${BLUE}${BOLD}║                                                                                   ║${NC}"
echo -e "${BLUE}${BOLD}╚═══════════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Safety banner for real sources mode
if [[ "$REAL_SOURCES" == "1" ]]; then
  echo -e "${RED}${BOLD}╔═══════════════════════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${RED}${BOLD}║                                                                                   ║${NC}"
  echo -e "${RED}${BOLD}║                    ${BOLD}⚠ MODE LECTURE SEULE ACTIVÉ ⚠${RED}${BOLD}                              ║${NC}"
  echo -e "${RED}${BOLD}║                                                                                   ║${NC}"
  echo -e "${RED}${BOLD}║  ${BOLD}Note: Le test /tmp peut importer normalement.${RED}${BOLD}                                            ║${NC}"
  echo -e "${RED}${BOLD}║  ${BOLD}Aucun import ne sera effectué sur les sources réelles.${RED}${BOLD}                                 ║${NC}"
  echo -e "${RED}${BOLD}║  ${BOLD}Seules les opérations de lecture sont autorisées sur sources réelles:${RED}${BOLD}                  ║${NC}"
  echo -e "${RED}${BOLD}║  ${BOLD}  • Attachement de source (lecture)${RED}${BOLD}                                                      ║${NC}"
  echo -e "${RED}${BOLD}║  ${BOLD}  • Détection (scanning)${RED}${BOLD}                                                                 ║${NC}"
  echo -e "${RED}${BOLD}║  ${BOLD}  • Tests de déterminisme${RED}${BOLD}                                                                ║${NC}"
  echo -e "${RED}${BOLD}║                                                                                   ║${NC}"
  echo -e "${RED}${BOLD}║  ${BOLD}Les sources réelles ne seront JAMAIS modifiées.${RED}${BOLD}                                            ║${NC}"
  echo -e "${RED}${BOLD}║                                                                                   ║${NC}"
  echo -e "${RED}${BOLD}╚═══════════════════════════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  sleep 2  # Give user time to read
fi

# Run function
run() {
  if [[ "$VERBOSE" == "1" ]]; then
    echo -e "${YELLOW}  → Exécution:${NC} ${CYAN}$BIN $*${NC}" >&2
  fi
  $BIN "$@"
}

# Extract JSON from command output (handles build messages)
# Uses stdin to avoid "Argument list too long" errors with large outputs
extract_json() {
  local output="$1"
  # Try to find JSON object in output (look for { ... })
  echo "$output" | python3 -c "
import json, sys, re
text = sys.stdin.read()
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
"
}

assert_eq() {
  local got="$1" expected="$2" msg="$3"
  if [[ "$got" == "$expected" ]]; then
    success "$msg (valeur: $got)"
  else
    fail "$msg (obtenu='$got', attendu='$expected')"
  fi
}

assert_file_exists() {
  local path="$1"
  if [[ -f "$path" ]]; then
    success "Fichier existe: $path"
  else
    fail "Fichier attendu introuvable: $path"
  fi
}

assert_dir_exists() {
  local path="$1"
  if [[ -d "$path" ]]; then
    success "Répertoire existe: $path"
  else
    fail "Répertoire attendu introuvable: $path"
  fi
}

# Extract JSON value from JSON string
# Uses stdin to avoid "Argument list too long" errors with large JSON
json_get() {
  local json_str="$1"
  local python_expr="$2"
  echo "$json_str" | python3 -c "import json, sys; j=json.loads(sys.stdin.read()); $python_expr" 2>/dev/null || echo ""
}

# Test a real source (read-only: attach + detect only)
test_real_source() {
  local source_path="$1"
  local source_name=$(basename "$source_path")
  
  # Temporarily disable exit on error for this function
  set +e
  
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${CYAN}${BOLD}Source:${NC} ${CYAN}$source_path${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  
  # Check if path exists
  if [[ ! -d "$source_path" ]]; then
    echo -e "${YELLOW}⚠ Chemin introuvable, ignoré${NC}"
    set -e
    return 1
  fi
  
  # Check if readable
  if [[ ! -r "$source_path" ]]; then
    echo -e "${YELLOW}⚠ Chemin non lisible, ignoré${NC}"
    set -e
    return 1
  fi
  
  local start_time=$(date +%s)
  
  # Attach source
  echo -e "${CYAN}Attachement de la source...${NC}"
  local attach_output=$(run source attach "$source_path" --json 2>&1 || true)
  local attach_json=$(extract_json "$attach_output")
  
  if [[ -z "$attach_json" ]]; then
    echo -e "${YELLOW}⚠ Échec d'attachement (peut être dû aux permissions)${NC}"
    echo -e "${YELLOW}   Sortie: ${attach_output:0:200}...${NC}"
    set -e
    return 1
  fi
  
  local source_id=$(json_get "$attach_json" "print(j.get('sourceId', j.get('source_id', j.get('id', ''))))")
  
  if [[ -z "$source_id" ]]; then
    echo -e "${YELLOW}⚠ Impossible d'extraire sourceId${NC}"
    set -e
    return 1
  fi
  
  success "Source attachée: $source_id"
  
  # First detect
  echo -e "${CYAN}Première détection...${NC}"
  local detect1_output=$(run detect "$source_id" --json 2>&1 || true)
  local detect1_json=$(extract_json "$detect1_output")
  
  if [[ -z "$detect1_json" ]]; then
    echo -e "${YELLOW}⚠ Échec de la première détection${NC}"
    set -e
    return 1
  fi
  
  local total1=$(json_get "$detect1_json" "print(j.get('summary', {}).get('totalScanned', 0))")
  local new1=$(json_get "$detect1_json" "print(j.get('summary', {}).get('newItems', 0))")
  local known1=$(json_get "$detect1_json" "print(j.get('summary', {}).get('knownItems', 0))")
  local candidates1=$(json_get "$detect1_json" "print(len(j.get('candidates', [])))")
  
  info "Première détection: scanné=$total1, nouveau=$new1, connu=$known1, candidats=$candidates1"
  
  # Second detect (for determinism)
  echo -e "${CYAN}Deuxième détection (test de déterminisme)...${NC}"
  local detect2_output=$(run detect "$source_id" --json 2>&1 || true)
  local detect2_json=$(extract_json "$detect2_output")
  
  if [[ -z "$detect2_json" ]]; then
    echo -e "${YELLOW}⚠ Échec de la deuxième détection${NC}"
    set -e
    return 1
  fi
  
  local total2=$(json_get "$detect2_json" "print(j.get('summary', {}).get('totalScanned', 0))")
  local new2=$(json_get "$detect2_json" "print(j.get('summary', {}).get('newItems', 0))")
  local known2=$(json_get "$detect2_json" "print(j.get('summary', {}).get('knownItems', 0))")
  local candidates2=$(json_get "$detect2_json" "print(len(j.get('candidates', [])))")
  
  info "Deuxième détection: scanné=$total2, nouveau=$new2, connu=$known2, candidats=$candidates2"
  
  # Assert determinism
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  
  local determinism_ok=true
  
  if [[ "$total1" != "$total2" ]]; then
    echo -e "${RED}✗ ÉCHEC DÉTERMINISME: totalScanned diffère ($total1 vs $total2)${NC}"
    determinism_ok=false
  else
    success "Déterminisme: totalScanned identique ($total1)"
  fi
  
  if [[ "$new1" != "$new2" ]]; then
    echo -e "${RED}✗ ÉCHEC DÉTERMINISME: newItems diffère ($new1 vs $new2)${NC}"
    determinism_ok=false
  else
    success "Déterminisme: newItems identique ($new1)"
  fi
  
  if [[ "$known1" != "$known2" ]]; then
    echo -e "${RED}✗ ÉCHEC DÉTERMINISME: knownItems diffère ($known1 vs $known2)${NC}"
    determinism_ok=false
  else
    success "Déterminisme: knownItems identique ($known1)"
  fi
  
  if [[ -n "$candidates1" && -n "$candidates2" && "$candidates1" != "$candidates2" ]]; then
    echo -e "${RED}✗ ÉCHEC DÉTERMINISME: candidates diffère ($candidates1 vs $candidates2)${NC}"
    determinism_ok=false
  elif [[ -n "$candidates1" && -n "$candidates2" ]]; then
    success "Déterminisme: candidates identique ($candidates1)"
  fi
  
  echo -e "${CYAN}Durée: ${duration}s${NC}"
  
  # Re-enable exit on error
  set -e
  
  if [[ "$determinism_ok" == "true" ]]; then
    success "Test de déterminisme réussi pour $source_name"
    return 0
  else
    echo -e "${RED}✗ Test de déterminisme échoué pour $source_name${NC}" >&2
    return 1
  fi
}

# --- setup ---
step "Setup"
STEP_START=$(step_start)

if [[ "$VERBOSE" == "1" ]]; then
  echo -e "${CYAN}Nettoyage des répertoires temporaires...${NC}"
fi
rm -rf "$LIB" "$LIB_MOVED" "$SRC"
mkdir -p "$SRC/sub"
if [[ "$VERBOSE" == "1" ]]; then
  success "Répertoires nettoyés"
fi

if [[ "$VERBOSE" == "1" ]]; then
  echo -e "${CYAN}Création de fichiers média de test...${NC}"
fi
printf "fake" > "$SRC/IMG_0001.HEIC"
printf "fake" > "$SRC/IMG_0002.JPG"
printf "fake" > "$SRC/sub/VID_0003.MOV"
printf "fake" > "$SRC/sub/IMG_0004.PNG"

# Set deterministic mtimes (2024-01 through 2024-04)
touch -t 202401021200 "$SRC/IMG_0001.HEIC"
touch -t 202402031200 "$SRC/IMG_0002.JPG"
touch -t 202403041200 "$SRC/sub/VID_0003.MOV"
touch -t 202404051200 "$SRC/sub/IMG_0004.PNG"
if [[ "$VERBOSE" == "1" ]]; then
  success "4 fichiers média créés (2 images, 1 vidéo, 1 image dans sous-dossier)"
fi

STEP_DURATION=$(step_end "$STEP_START")
record_step "Setup" "PASS" "4 fake media files" "$STEP_DURATION"

# --- create library ---
step "Library create"
STEP_START=$(step_start)

test_header "Création de la bibliothèque avec chemin positionnel"
run library create "$LIB"

assert_dir_exists "$LIB/.mediahub"
assert_file_exists "$LIB/.mediahub/library.json"

# Set library context for subsequent commands
export MEDIAHUB_LIBRARY="$LIB"
info "Variable d'environnement MEDIAHUB_LIBRARY définie: $LIB"

STEP_DURATION=$(step_end "$STEP_START")
record_step "Library create" "PASS" "$LIB" "$STEP_DURATION"

# --- attach source ---
step "Source attach"
STEP_START=$(step_start)

test_header "Attachement de la source avec extraction de l'ID"
ATTACH_JSON=$(run source attach "$SRC" --json)
SID=$(python3 -c "import json, sys; j=json.loads(sys.argv[1]); print(j.get('sourceId', j.get('source_id', j.get('id', ''))))" "$ATTACH_JSON")
[[ -n "$SID" ]] || fail "sourceId manquant dans la sortie d'attachement"
success "Source attachée avec succès"
info "Source ID: ${BOLD}$SID${NC}"

STEP_DURATION=$(step_end "$STEP_START")
SID_SHORT="${SID:0:8}...${SID: -4}"
record_step "Source attach" "PASS" "SID=$SID_SHORT" "$STEP_DURATION"

# --- detect (first run) ---
step "Detect (pre-import)"
STEP_START=$(step_start)

test_header "Détection initiale (devrait trouver 4 nouveaux éléments)"
DETECT1_JSON=$(run detect "$SID" --json)
TOTAL1=$(python3 -c "import json, sys; j=json.loads(sys.argv[1]); print(j['summary']['totalScanned'])" "$DETECT1_JSON")
NEW1=$(python3 -c "import json, sys; j=json.loads(sys.argv[1]); print(j['summary']['newItems'])" "$DETECT1_JSON")
assert_eq "$TOTAL1" "4" "Total d'éléments scannés"
assert_eq "$NEW1" "4" "Nouveaux éléments détectés"

STEP_DURATION=$(step_end "$STEP_START")
record_step "Detect (pre-import)" "PASS" "scanned=$TOTAL1 new=$NEW1 known=0" "$STEP_DURATION"

# --- dry-run import test ---
step "Import (dry-run)"
STEP_START=$(step_start)

test_header "Dry-run import (devrait prévisualiser 4 éléments sans importer)"
DRYRUN_JSON=$(run import "$SID" --all --dry-run --json)
# Dry-run output is wrapped in envelope: {"dryRun": true, "result": {...}}
DRYRUN_FLAG=$(python3 -c "import json, sys; j=json.loads(sys.argv[1]); print(j.get('dryRun', False))" "$DRYRUN_JSON" 2>/dev/null || echo "false")
if [[ "$DRYRUN_FLAG" == "True" || "$DRYRUN_FLAG" == "true" ]]; then
  # Extract result from envelope
  DRYRUN_RESULT=$(python3 -c "import json, sys; j=json.loads(sys.argv[1]); print(json.dumps(j.get('result', j)))" "$DRYRUN_JSON" 2>/dev/null || echo "$DRYRUN_JSON")
  DRYRUN_IMPORTED=$(python3 -c "import json, sys; j=json.loads(sys.argv[1]); print(j.get('summary', {}).get('imported', 0))" "$DRYRUN_RESULT" 2>/dev/null || echo "0")
else
  # Fallback: try to parse as direct ImportResult
  DRYRUN_IMPORTED=$(python3 -c "import json, sys; j=json.loads(sys.argv[1]); print(j.get('summary', {}).get('imported', 0))" "$DRYRUN_JSON" 2>/dev/null || echo "0")
fi
assert_eq "$DRYRUN_IMPORTED" "4" "Éléments prévisualisés en dry-run"

# Verify no files were actually imported (dry-run should not copy files)
test_header "Vérification qu'aucun fichier n'a été importé (dry-run)"
if [[ ! -d "$LIB/2024" ]]; then
  success "Aucun fichier importé (dry-run fonctionne correctement)"
else
  # Check if any files exist (they shouldn't in dry-run)
  FILES_COUNT=$(find "$LIB/2024" -type f 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$FILES_COUNT" == "0" ]]; then
    success "Aucun fichier importé (dry-run fonctionne correctement)"
  else
    fail "Des fichiers ont été importés lors du dry-run (devrait être 0, trouvé: $FILES_COUNT)"
  fi
fi

STEP_DURATION=$(step_end "$STEP_START")
record_step "Import (dry-run)" "PASS" "preview=$DRYRUN_IMPORTED files=0" "$STEP_DURATION"

# --- import all ---
step "Import"
STEP_START=$(step_start)

test_header "Import de tous les éléments (devrait importer 4)"
IMPORT1_JSON=$(run import "$SID" --all --yes --json)
IMPORTED1=$(python3 -c "import json, sys; j=json.loads(sys.argv[1]); print(j['summary']['imported'])" "$IMPORT1_JSON")
FAILED1=$(python3 -c "import json, sys; j=json.loads(sys.argv[1]); print(j['summary']['failed'])" "$IMPORT1_JSON")
assert_eq "$IMPORTED1" "4" "Éléments importés"
assert_eq "$FAILED1" "0" "Éléments échoués"

# Verify imported files exist under /tmp/mh_library/2024/<MM>/...
test_header "Vérification des fichiers importés"
info "Vérification de la structure YYYY/MM..."
assert_file_exists "$LIB/2024/01/IMG_0001.HEIC"
assert_file_exists "$LIB/2024/02/IMG_0002.JPG"
assert_file_exists "$LIB/2024/03/VID_0003.MOV"
assert_file_exists "$LIB/2024/04/IMG_0004.PNG"
success "Tous les fichiers sont présents dans la structure attendue"

STEP_DURATION=$(step_end "$STEP_START")
record_step "Import" "PASS" "imported=$IMPORTED1 failed=$FAILED1" "$STEP_DURATION"

# --- detect after import ---
step "Detect (post-import)"
STEP_START=$(step_start)

test_header "Détection après import (devrait trouver 0 nouveau, 4 connus)"
DETECT2_JSON=$(run detect "$SID" --json)
TOTAL2=$(python3 -c "import json, sys; j=json.loads(sys.argv[1]); print(j['summary']['totalScanned'])" "$DETECT2_JSON")
NEW2=$(python3 -c "import json, sys; j=json.loads(sys.argv[1]); print(j['summary']['newItems'])" "$DETECT2_JSON")
KNOWN2=$(python3 -c "import json, sys; j=json.loads(sys.argv[1]); print(j['summary']['knownItems'])" "$DETECT2_JSON")
assert_eq "$NEW2" "0" "Nouveaux éléments (devrait être 0)"
assert_eq "$KNOWN2" "4" "Éléments connus (devrait être 4)"

STEP_DURATION=$(step_end "$STEP_START")
record_step "Detect (post-import)" "PASS" "scanned=$TOTAL2 new=$NEW2 known=$KNOWN2" "$STEP_DURATION"

# --- idempotence: import again should import 0 ---
step "Import (idempotence)"
STEP_START=$(step_start)

test_header "Réimport (devrait importer 0 élément - idempotence)"
IMPORT2_JSON=$(run import "$SID" --all --yes --json)
# Handle case where no new items returns {"message": "..."} instead of full ImportResult
IMPORTED2=$(python3 -c "import json, sys; j=json.loads(sys.argv[1]); print(j.get('summary', {}).get('imported', 0) if 'summary' in j else 0)" "$IMPORT2_JSON")
assert_eq "$IMPORTED2" "0" "Éléments importés lors du réimport (devrait être 0)"

STEP_DURATION=$(step_end "$STEP_START")
record_step "Import (idempotence)" "PASS" "imported=$IMPORTED2" "$STEP_DURATION"

# --- move library test ---
step "Move + status"
STEP_START=$(step_start)

test_header "Déplacement de la bibliothèque"
info "Déplacement de $LIB vers $LIB_MOVED"
rm -rf "$LIB_MOVED"
mv "$LIB" "$LIB_MOVED"
export MEDIAHUB_LIBRARY="$LIB_MOVED"
success "Bibliothèque déplacée"

# Get original libraryId from library.json
ORIG_LIB_ID=$(python3 -c "import json; j=json.load(open('$LIB_MOVED/.mediahub/library.json')); print(j['libraryId'])" 2>/dev/null || echo "")

# status should work and libraryId should be unchanged
# Note: status JSON uses 'identifier' key, not 'libraryId'
test_header "Vérification du statut après déplacement"
STATUS_MOVED_OUTPUT=$(run status --json 2>&1)
STATUS_MOVED_JSON=$(extract_json "$STATUS_MOVED_OUTPUT")
if [[ -z "$STATUS_MOVED_JSON" ]]; then
  echo -e "${RED}DEBUG: sortie du status: $STATUS_MOVED_OUTPUT${NC}" >&2
  fail "La commande status n'a retourné aucun JSON valide"
fi
STATUS_MOVED_ID=$(python3 -c "import json, sys; j=json.loads(sys.argv[1]); print(j.get('identifier', ''))" "$STATUS_MOVED_JSON" 2>/dev/null || echo "")
if [[ -z "$STATUS_MOVED_ID" ]]; then
  echo -e "${RED}DEBUG: JSON extrait: $STATUS_MOVED_JSON${NC}" >&2
  fail "Impossible d'extraire l'identifiant du JSON de status"
fi
if [[ -n "$ORIG_LIB_ID" ]]; then
  assert_eq "$STATUS_MOVED_ID" "$ORIG_LIB_ID" "ID de bibliothèque (devrait être inchangé après déplacement)"
fi

if [[ "$VERBOSE" == "1" ]]; then
  step "Arborescence finale de la bibliothèque"
  find "$LIB_MOVED" -maxdepth 3 -type f | sed "s|$LIB_MOVED/||" | sort
fi

STEP_DURATION=$(step_end "$STEP_START")
record_step "Move + status" "PASS" "ID unchanged" "$STEP_DURATION"

# Track test results
TMP_TEST_PASSED=true
REAL_SOURCES_TESTED=0
REAL_SOURCES_SKIPPED=0
REAL_SOURCES_FAILED=0

# --- real source tests (optional) ---
if [[ "$REAL_SOURCES" == "1" ]]; then
  step "Tests sur sources réelles (lecture seule)"
  
  # Create or reuse library for real sources
  if [[ ! -d "$LIB_REAL" ]]; then
    test_header "Création de bibliothèque pour tests réels"
    run library create "$LIB_REAL"
    export MEDIAHUB_LIBRARY="$LIB_REAL"
    success "Bibliothèque créée: $LIB_REAL"
  else
    export MEDIAHUB_LIBRARY="$LIB_REAL"
    info "Réutilisation de la bibliothèque: $LIB_REAL"
  fi
  
  # Test each real source
  set +e  # Temporarily disable exit on error for loop
  for real_source in "${REAL_SOURCE_PATHS[@]}"; do
    if test_real_source "$real_source"; then
      ((REAL_SOURCES_TESTED++))
    else
      if [[ -d "$real_source" ]]; then
        ((REAL_SOURCES_FAILED++))
      else
        ((REAL_SOURCES_SKIPPED++))
      fi
    fi
  done
  set -e  # Re-enable exit on error
  
  echo ""
  echo -e "${CYAN}Résumé des tests sur sources réelles:${NC}"
  echo -e "  ${GREEN}✓ Testées avec succès: $REAL_SOURCES_TESTED${NC}"
  echo -e "  ${YELLOW}⚠ Ignorées (introuvables): $REAL_SOURCES_SKIPPED${NC}"
  if [[ $REAL_SOURCES_FAILED -gt 0 ]]; then
    echo -e "  ${RED}✗ Échouées: $REAL_SOURCES_FAILED${NC}"
  fi
else
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${CYAN}Tests sur sources réelles: ${YELLOW}DÉSACTIVÉS${NC}"
  echo -e "${CYAN}Pour activer: ${BOLD}$0 -real${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
fi

# --- final summary ---
render_summary_table

# Real sources summary (if enabled)
if [[ "$REAL_SOURCES" == "1" ]]; then
  echo ""
  echo -e "${CYAN}${BOLD}Real Sources Summary:${NC}"
  echo -e "${CYAN}  • Tested: $REAL_SOURCES_TESTED${NC}"
  echo -e "${CYAN}  • Skipped: $REAL_SOURCES_SKIPPED${NC}"
  if [[ $REAL_SOURCES_FAILED -gt 0 ]]; then
    echo -e "${RED}  • Failed: $REAL_SOURCES_FAILED${NC}"
    echo ""
    echo -e "${RED}${BOLD}⚠ SOME REAL SOURCE TESTS FAILED${NC}"
  fi
  echo ""
fi

# Exit with error if real source tests failed
if [[ "$REAL_SOURCES" == "1" && $REAL_SOURCES_FAILED -gt 0 ]]; then
  exit 1
fi
