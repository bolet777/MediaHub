#!/usr/bin/env bash
set -euo pipefail

# MediaHub CLI Smoke Test
# - Uses ONLY /tmp paths
# - SAFE: no touching any real libraries

BIN="swift run mediahub"

LIB="/tmp/mh_library"
LIB_MOVED="/tmp/mh_library_moved"
SRC="/tmp/mh_source"

# --- colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# --- helpers ---
fail() { 
  echo -e "${RED}${BOLD}✗ ERREUR:${NC} ${RED}$*${NC}" >&2
  exit 1
}

success() {
  echo -e "${GREEN}${BOLD}✓${NC} ${GREEN}$*${NC}"
}

info() {
  echo -e "${CYAN}ℹ${NC} ${CYAN}$*${NC}"
}

step() {
  echo ""
  echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}${BOLD}  $*${NC}"
  echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

test_header() {
  echo ""
  echo -e "${MAGENTA}${BOLD}▶ Test:${NC} ${MAGENTA}$*${NC}"
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
echo -e "${BLUE}${BOLD}║  ${YELLOW}⚠ Utilise uniquement des chemins /tmp - SÉCURISÉ${BLUE}${BOLD}                              ║${NC}"
echo -e "${BLUE}${BOLD}║                                                                                   ║${NC}"
echo -e "${BLUE}${BOLD}╚═══════════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

run() {
  echo -e "${YELLOW}  → Exécution:${NC} ${CYAN}$BIN $*${NC}" >&2
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

# --- setup ---
step "Préparation de l'environnement de test"

echo -e "${CYAN}Nettoyage des répertoires temporaires...${NC}"
rm -rf "$LIB" "$LIB_MOVED" "$SRC"
mkdir -p "$SRC/sub"
success "Répertoires nettoyés"

echo -e "${CYAN}Création de fichiers média de test...${NC}"
printf "fake" > "$SRC/IMG_0001.HEIC"
printf "fake" > "$SRC/IMG_0002.JPG"
printf "fake" > "$SRC/sub/VID_0003.MOV"
printf "fake" > "$SRC/sub/IMG_0004.PNG"

# Set deterministic mtimes (2024-01 through 2024-04)
touch -t 202401021200 "$SRC/IMG_0001.HEIC"
touch -t 202402031200 "$SRC/IMG_0002.JPG"
touch -t 202403041200 "$SRC/sub/VID_0003.MOV"
touch -t 202404051200 "$SRC/sub/IMG_0004.PNG"
success "4 fichiers média créés (2 images, 1 vidéo, 1 image dans sous-dossier)"

# --- create library ---
step "Création de la bibliothèque"

test_header "Création de la bibliothèque avec chemin positionnel"
run library create "$LIB"

assert_dir_exists "$LIB/.mediahub"
assert_file_exists "$LIB/.mediahub/library.json"

# Set library context for subsequent commands
export MEDIAHUB_LIBRARY="$LIB"
info "Variable d'environnement MEDIAHUB_LIBRARY définie: $LIB"

# --- attach source ---
step "Attachement de la source"

test_header "Attachement de la source avec extraction de l'ID"
ATTACH_JSON=$(run source attach "$SRC" --json)
SID=$(python3 -c "import json, sys; j=json.loads(sys.argv[1]); print(j.get('sourceId', j.get('source_id', j.get('id', ''))))" "$ATTACH_JSON")
[[ -n "$SID" ]] || fail "sourceId manquant dans la sortie d'attachement"
success "Source attachée avec succès"
info "Source ID: ${BOLD}$SID${NC}"

# --- detect (first run) ---
step "Première détection"

test_header "Détection initiale (devrait trouver 4 nouveaux éléments)"
DETECT1_JSON=$(run detect "$SID" --json)
TOTAL1=$(python3 -c "import json, sys; j=json.loads(sys.argv[1]); print(j['summary']['totalScanned'])" "$DETECT1_JSON")
NEW1=$(python3 -c "import json, sys; j=json.loads(sys.argv[1]); print(j['summary']['newItems'])" "$DETECT1_JSON")
assert_eq "$TOTAL1" "4" "Total d'éléments scannés"
assert_eq "$NEW1" "4" "Nouveaux éléments détectés"

# --- import all ---
step "Import des éléments détectés"

test_header "Import de tous les éléments (devrait importer 4)"
IMPORT1_JSON=$(run import "$SID" --all --json)
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

# --- detect after import ---
step "Détection après import"

test_header "Détection après import (devrait trouver 0 nouveau, 4 connus)"
DETECT2_JSON=$(run detect "$SID" --json)
NEW2=$(python3 -c "import json, sys; j=json.loads(sys.argv[1]); print(j['summary']['newItems'])" "$DETECT2_JSON")
KNOWN2=$(python3 -c "import json, sys; j=json.loads(sys.argv[1]); print(j['summary']['knownItems'])" "$DETECT2_JSON")
assert_eq "$NEW2" "0" "Nouveaux éléments (devrait être 0)"
assert_eq "$KNOWN2" "4" "Éléments connus (devrait être 4)"

# --- idempotence: import again should import 0 ---
step "Test d'idempotence"

test_header "Réimport (devrait importer 0 élément - idempotence)"
IMPORT2_JSON=$(run import "$SID" --all --json)
# Handle case where no new items returns {"message": "..."} instead of full ImportResult
IMPORTED2=$(python3 -c "import json, sys; j=json.loads(sys.argv[1]); print(j.get('summary', {}).get('imported', 0) if 'summary' in j else 0)" "$IMPORT2_JSON")
assert_eq "$IMPORTED2" "0" "Éléments importés lors du réimport (devrait être 0)"

# --- move library test ---
step "Test de déplacement de bibliothèque"

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

step "Arborescence finale de la bibliothèque"
find "$LIB_MOVED" -maxdepth 3 -type f | sed "s|$LIB_MOVED/||" | sort

echo ""
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}  ✓ TOUS LES TESTS ONT RÉUSSI${NC}"
echo -e "${GREEN}${BOLD}  Le test de fumée est passé avec succès !${NC}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
