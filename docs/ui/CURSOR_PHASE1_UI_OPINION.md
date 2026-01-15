# Cursor Phase 1 — Avis sur la Faisabilité UI SwiftUI

**Date**: 2026-01-27  
**Auteur**: Cursor (agent dev senior)  
**Contexte**: Analyse de faisabilité avant implémentation UI SwiftUI pour MediaHub

---

## 1. Executive Summary

- **Globalement: GO avec risques** — L'UI est faisable mais nécessite des clarifications techniques et des ajustements de design avant de démarrer
- Architecture CLI/core solide avec JSON output disponible pour toutes les commandes critiques
- Reports/audit stockés en JSON dans `.mediahub/sources/{sourceId}/detections/` et `imports/` — parfait pour l'UI
- Progress/cancel: **UNKNOWN** — Le core n'expose pas d'API de progression en temps réel ni de cancellation; le CLI utilise SIGINT mais c'est CLI-only
- Permissions macOS: **RISQUE OUI** — L'app devra gérer les permissions volumes/sandbox; le core détecte les erreurs mais l'UI devra demander explicitement
- Mapping CLI→UI clair dans `CLI_UI_MAPPING.md` — bonne base contractuelle
- Source de vérité: `UI_VISION.md` + `IA_MAP_V1.md` + `CLI_UI_MAPPING.md` (le document `ui-design-proposal.md` est un brainstorm non contractuel)
- **REQUIREMENT v1 OBLIGATOIRE**: Filtrage par type média (Images/Vidéos/Les deux) — **NON implémenté**, nécessite changements CORE/CLI (drapeau #2)
- **REQUIREMENT v1 OBLIGATOIRE**: Statistiques par bibliothèque (total, répartition année/type) — **NON implémenté**, nécessite changements CORE/CLI (drapeau #3)
- Découverte bibliothèques: **OUI** — `LibraryDiscoverer.discoverAll()` disponible, scanne volumes montés

---

## 2. Ce qui est très bien

- **JSON output complet**: Toutes les commandes critiques (`library`, `source`, `detect`, `import`, `status`, `index`) supportent `--json` avec structures bien définies (`OutputFormatting.swift`). **Note**: JSON reste le contrat CLI; l'UI consommera les types Swift du core directement (pas de parsing JSON).
- **Reports persistants**: Detection et import results stockés en JSON dans `.mediahub/sources/{sourceId}/detections/{timestamp}.json` et `imports/{timestamp}.json` — l'UI peut lire l'historique sans re-exécuter
- **Dry-run par défaut**: Toutes les opérations destructives supportent `--dry-run` (adopt, import, index hash) — aligné avec "dry-run par défaut" de la vision
- **Architecture CLI/core propre**: Séparation claire, pas de logique métier dans CLI — l'UI peut appeler le core directement ou wrapper CLI
- **Error handling structuré**: Le core expose des erreurs typées (`LibraryAdoptionError`, `DetectionResultError`, etc.) avec `LocalizedError` — l'UI peut formater proprement
- **Validation robuste**: `SourceValidator`, `LibraryValidation` — l'UI peut pré-valider avant d'appeler le core

---

## 3. Les 10 plus gros drapeaux (priorisés)

### 1. **Progress/Cancel API manquante** — BLOCKER (vraie UX) / HIGH (P1 avec spinner)
**Impact**: **BLOCKER** pour vraie UX avec progression détaillée + cancel, **HIGH** pour P1 avec spinner simple  
**Pourquoi**: Pour une vraie UX (pas juste spinner), l'UI doit afficher progression réelle (X/Y items) et permettre cancellation. Le CLI utilise `ProgressIndicator` qui écrit sur stderr, mais le core n'expose pas d'API de progression en temps réel. Pas de cancellation non plus (SIGINT est CLI-only). **Pour P1**, un spinner simple est acceptable (Slice #3), mais pour itérations futures, une API progress/cancel est nécessaire.  
**Où**: `Sources/MediaHubCLI/ProgressIndicator.swift` (CLI-only), `Sources/MediaHub/DetectionOrchestration.swift`, `Sources/MediaHub/ImportExecution.swift` (pas d'API progress)  
**Comment vérifier**: Chercher `Progress` ou callback de progression dans le core — actuellement absent. L'UI devra soit wrapper CLI avec parsing stderr (fragile), soit ajouter API progress au core.

### 2. **Filtrage par type média — REQUIREMENT v1 OBLIGATOIRE** — BLOCKER
**Impact**: **CORE / CLI** — Changements nécessaires dans le core et le CLI  
**Sévérité**: BLOCKER (requirement v1 obligatoire)  
**Pourquoi**: **REQUIREMENT v1**: Pour CHAQUE source, l'utilisateur doit choisir si la source fournit Images / Vidéos / Images+Vidéos. Ce choix est **PERSISTANT par source** et impacte la détection, l'import, et les stats par bibliothèque.  
**Où**: 
- `Sources/MediaHub/Source.swift` (structure `Source` — ajouter champ `mediaTypes`)
- `Sources/MediaHub/SourceScanning.swift` (méthode `scan()` — ajouter filtre)
- `Sources/MediaHub/DetectionOrchestration.swift` (propager filtre)
- `Sources/MediaHub/ImportExecution.swift` (respecter filtre si nécessaire)
- `Sources/MediaHub/SourceAssociation.swift` (persistance du choix)
- `Sources/MediaHubCLI/SourceCommand.swift` (commande `source attach` — accepter paramètres)

**Solution minimale côté core/CLI**:

1. **Ajouter enum `MediaType`** dans `Source.swift`: `enum MediaType: String, Codable { case image, video }`

2. **Modifier `Source` struct**: Ajouter champ `mediaTypes: Set<MediaType>` avec default `[.image, .video]` dans `init()`

3. **Modifier `SourceScanner.scan()`**: Filtrer selon `source.mediaTypes` lors du scan (filtre appliqué au niveau scan, donc détection ne liste que les items autorisés)

4. **Modifier `DetectionOrchestrator.executeDetection()`**: Utiliser `source.mediaTypes` — le filtre s'applique au scan, donc `DetectionResult` ne contient que les items filtrés, et l'import ne voit que ce set filtré

5. **Modifier `SourceCommand.attach`**: Ajouter `@Option --media-types` avec format strict: `"images"|"videos"|"both"` (parser strictement)

**Impact sur import**: Le filtre s'applique au stade scan (détection), donc l'import ne voit que les items autorisés par `source.mediaTypes`. Pas besoin de filtrer à nouveau lors de l'import.

**Backward compatibility**:
- **Sources existantes**: Si `mediaTypes` absent lors du decoding JSON → default `[.image, .video]` (comportement actuel)
- **Implémentation**: Utiliser `init(from decoder: Decoder)` custom ou champ optionnel avec fallback dans `init()`
- **Migration**: Toutes sources existantes héritent automatiquement de "both" (images + vidéos)

**Commandes/APIs à modifier**:
- ✅ `Source` struct (ajouter champ `mediaTypes`)
- ✅ `SourceScanner.scan()` (ajouter filtre)
- ✅ `DetectionOrchestrator.executeDetection()` (utiliser `source.mediaTypes`)
- ✅ `SourceCommand.attach` (accepter `--media-types`)
- ✅ `SourceAssociationManager` (persistance automatique via `Source`)

**Migration**: Sources existantes sans `mediaTypes` → default `[.image, .video]` (comportement actuel).

### 3. **Statistiques bibliothèque — REQUIREMENT v1 OBLIGATOIRE** — BLOCKER
**Impact**: **CORE / CLI** — Changements nécessaires dans le core et le CLI  
**Sévérité**: BLOCKER (requirement v1 obligatoire)  
**Pourquoi**: **REQUIREMENT v1**: L'UI doit afficher pour chaque bibliothèque: nombre total d'éléments, répartition par année, répartition par type (image/vidéo). Ces stats sont **fonctionnelles** (pas décoratives) et doivent être exposées par le core (index ou commande dédiée), pas calculées ad-hoc dans l'UI.  
**Où**: 
- `Sources/MediaHub/BaselineIndex.swift` (structure `BaselineIndex` — ajouter méthodes stats)
- `Sources/MediaHubCLI/StatusCommand.swift` (exposer stats dans output)
- `Sources/MediaHub/LibraryContentQuery.swift` (si scan nécessaire)

**Solution minimale côté core/CLI**:

1. **Ajouter structure `LibraryStatistics`**: `totalItems: Int`, `itemsByYear: [Int: Int]`, `itemsByType: [String: Int]`

2. **Ajouter méthode `BaselineIndex.computeStatistics()`**: 
   - **Source canonique pour année**: **Option 1 (recommandée)** — Extraire depuis path si structure `YYYY/MM/filename.ext` (rapide, stable, garanti pour imports MediaHub)
   - **Option 2 (fallback)** — Extraire depuis `entry.mtime` (ISO8601) si path ne contient pas YYYY/MM (pour bibliothèques adoptées)
   - **Type**: Déterminer via `MediaFileFormat.isImageFile()` / `isVideoFile()` depuis extension

3. **Fallback si index non disponible**: `LibraryContentQuery.computeStatistics()` — scan complet (plus lent)

4. **Modifier `StatusCommand`**: Appeler `computeStatistics()` et passer à `StatusFormatter`

5. **Modifier `StatusFormatter`**: Afficher statistics dans output (human-readable et JSON)

**Points d'injection**:
- `BaselineIndex.computeStatistics()` — itérer sur `entries`, extraire année depuis path (priorité) ou mtime (fallback)
- `LibraryContentQuery.computeStatistics()` — scan complet si index absent
- `StatusCommand.run()` — appeler computeStatistics et passer à formatter

**Commandes/APIs à modifier**:
- ✅ `BaselineIndex` (ajouter méthode `computeStatistics()`)
- ✅ `LibraryContentQuery` (ajouter méthode `computeStatistics()` si index non disponible)
- ✅ `StatusCommand` (appeler computeStatistics et passer à formatter)
- ✅ `StatusFormatter` (afficher statistics dans output)
- ✅ Nouveau type `LibraryStatistics` (structure de données)

**Performance**: Utiliser `BaselineIndex` en priorité (rapide), fallback sur scan complet si index non disponible (plus lent mais fonctionnel).

**Contrat JSON `status --json`**:
- `mediahub status --json` doit inclure un champ `libraryStatistics` (optionnel si stats non disponibles)
- Format: `{ "libraryStatistics": { "totalItems": 1234, "itemsByYear": { 2024: 500, 2023: 734 }, "itemsByType": { "image": 1000, "video": 234 } } }`
- Version: v1 (pas de versioning séparé pour stats, fait partie du contrat Status v1)

### 4. **Permissions macOS / Sandbox** — HIGH
**Impact**: HIGH  
**Pourquoi**: L'app SwiftUI devra accéder aux volumes montés (ex: `/Volumes/Photos`). macOS App Sandbox bloque l'accès aux volumes externes sans permission explicite. Le core détecte les erreurs (`PermissionErrorHandler`) mais l'UI devra demander les permissions via `NSOpenPanel` ou entitlements.  
**Où**: `Sources/MediaHub/LibraryDiscovery.swift` (scanne volumes), `Sources/MediaHub/LibraryValidation.swift` (valide permissions)  
**Comment vérifier**: Vérifier si l'app SwiftUI actuelle (`MediaHubUI`) a des entitlements dans `Package.swift` ou `Info.plist`. Tester accès volume externe en sandbox.

### 5. **Clarification navigation: onglets vs single surface** — MED
**Impact**: MED  
**Pourquoi**: Le brainstorm (`ui-design-proposal.md`) suggère des onglets ("Vue d'ensemble", "Sources", "Historique") mais `IA_MAP_V1.md` (source de vérité) dit "No tabs visible by default" et "one library, one surface". **Pas une contradiction réelle** puisque le proposal est non contractuel, mais l'UI devra suivre `IA_MAP_V1.md` (progressive disclosure sans onglets par défaut).  
**Où**: `docs/ui/ui-design-proposal.md` (ligne 152-180, brainstorm), `docs/ui/IA_MAP_V1.md` (ligne 49-69, source de vérité)  
**Comment vérifier**: Suivre `IA_MAP_V1.md` pour la navigation. Le brainstorm peut servir d'inspiration mais n'est pas contractuel.

### 6. **Détection nécessite sourceId (UUID)** — MED
**Impact**: MED  
**Pourquoi**: `DetectCommand` prend un `sourceId` (UUID) en argument, pas un chemin. L'UI devra mapper chemin source → sourceId avant d'appeler détection. Pas bloquant mais ajoute une étape.  
**Où**: `Sources/MediaHubCLI/DetectCommand.swift` (ligne 23-24), `Sources/MediaHubCLI/ImportCommand.swift` (ligne 24-25)  
**Comment vérifier**: Vérifier si `SourceAssociationManager.retrieveSources()` retourne les sources avec `sourceId` — OUI, mais l'UI devra gérer ce mapping.

### 7. **Import nécessite détection préalable** — MED
**Impact**: MED  
**Pourquoi**: `ImportCommand` lit le dernier `DetectionResult` depuis disque (via `DetectionResultRetriever.retrieveLatest()`). L'UI doit s'assurer qu'une détection a été exécutée avant import, ou gérer le cas "no detection result".  
**Où**: `Sources/MediaHubCLI/ImportCommand.swift` (ligne 118-123)  
**Comment vérifier**: Tester flow: source attach → detect → import. Vérifier comportement si import sans détection.

### 8. **Confirmation interactive vs non-interactive** — MED
**Impact**: MED  
**Pourquoi**: Le CLI demande confirmation en mode interactif (TTY) mais requiert `--yes` en non-interactif. L'UI SwiftUI n'est pas un TTY, donc devra soit passer `--yes` (risque), soit implémenter sa propre confirmation (recommandé).  
**Où**: `Sources/MediaHubCLI/LibraryCommand.swift` (ligne 241-265), `Sources/MediaHubCLI/ImportCommand.swift` (ligne 140-171)  
**Comment vérifier**: Vérifier si l'UI doit wrapper CLI avec `--yes` ou appeler le core directement (core n'a pas de confirmation, c'est CLI-only).

### 9. **Historique: pas de commande dédiée** — LOW
**Impact**: LOW  
**Pourquoi**: Le brainstorm suggère afficher "Historique" (derniers imports/détections). Pas de commande CLI dédiée, mais les results sont stockés en JSON. L'UI devra lire directement les fichiers JSON depuis `.mediahub/sources/{sourceId}/detections/` et `imports/`.  
**Où**: `docs/ui/ui-design-proposal.md` (ligne 171-174, brainstorm), `Sources/MediaHub/DetectionResult.swift` (ligne 390-454), `Sources/MediaHub/ImportResult.swift` (ligne 399-463)  
**Comment vérifier**: Vérifier si `DetectionResultRetriever.retrieveAll()` et `ImportResultRetriever.retrieveAll()` sont publics — OUI, l'UI peut les utiliser.

### 10. **Collision policy: hardcodée à `.skip`** — LOW
**Impact**: LOW  
**Pourquoi**: `ImportCommand` hardcode `ImportOptions(collisionPolicy: .skip)` (ligne 190). Le brainstorm mentionne une préférence "Comportement des collisions" mais le CLI ne l'expose pas. L'UI devra soit modifier le core pour accepter une policy, soit wrapper avec une future option CLI.  
**Où**: `Sources/MediaHubCLI/ImportCommand.swift` (ligne 190), `docs/ui/ui-design-proposal.md` (ligne 405-408, brainstorm)  
**Comment vérifier**: Vérifier si `ImportExecutor.executeImport()` accepte une policy custom — OUI via `ImportOptions`, mais CLI ne l'expose pas.

---

## 4. Faisabilité par étapes (proposition courte)

### Slice UI #1: Shell minimal + Découverte bibliothèques
**Ce que ça inclut**:
- App SwiftUI avec sidebar listant les bibliothèques découvertes
- Appel direct au core: `LibraryDiscoverer.discoverAll()` au lancement
- Affichage liste bibliothèques (nom, chemin, ID)
- Sélection bibliothèque → affichage info basique (appel direct au core pour status)

**Architecture: UI→Core direct** (recommandé)
- **Justification**: 
  - `Package.swift` expose déjà `MediaHub` comme library (ligne 12-14)
  - Pas de parsing JSON fragile (accès direct aux types Swift: `DiscoveredLibrary`, `OpenedLibrary`)
  - Meilleure gestion d'erreurs (types d'erreur Swift: `LibraryDiscoveryError`, `LibraryOpeningError`)
  - Plus performant (pas de fork/process, pas de sérialisation JSON)
  - Aligné avec "UI never implements business logic" — l'UI utilise le core, pas le CLI
  - `CLI_UI_MAPPING.md` dit "maps to CLI commands" mais peut être interprété comme équivalence sémantique, pas appel CLI
- **Dépendances**:
  - Ajouter `MediaHub` comme dépendance dans `MediaHubUI` (via `Package.swift` local ou git)
  - Gestion permissions volumes (NSOpenPanel ou entitlements)
  - Appel direct: `LibraryDiscoverer.discoverAll()`, `LibraryContext.openLibrary()`, `SourceAssociationManager.retrieveSources()`, `BaselineIndexLoader.tryLoadBaselineIndex()`

**Risques**: Permissions macOS (drapeau #4), configuration dépendance MediaHub dans MediaHubUI

**Progress UI: Spinner simple accepté**
- **Justification**: 
  - Discovery: généralement < 5 secondes (SC-003: `< 5 seconds`)
  - Open library: < 2 secondes (SC-002: `< 2 seconds`)
  - Opérations ponctuelles, pas des batch operations
  - Spinner avec message "Découverte en cours..." ou "Ouverture..." suffit
  - Pas besoin de progress détaillé (X/Y items) pour ces opérations rapides

---

### Slice UI #2: Création/Adoption bibliothèque
**Ce que ça inclut**:
- Dialog création/adoption unifié (suggestion du brainstorm, aligné avec `CLI_UI_MAPPING.md`)
- NSOpenPanel pour sélection chemin
- Appel direct au core: `LibraryCreator.createLibrary()` ou `LibraryAdopter.adoptLibrary(dryRun: true)` puis `LibraryAdopter.adoptLibrary()`
- Affichage résultat (succès/erreur)

**Architecture: UI→Core direct** (recommandé)
- Appel direct: `LibraryCreator.createLibrary()`, `LibraryAdopter.adoptLibrary()`
- UI gère la confirmation (le core n'a pas de confirmation, c'est CLI-only)

**Dépendances**:
- Gestion erreurs (permissions, validation)
- Confirmation UI (le core n'a pas de confirmation)

**Risques**: Confirmation interactive (drapeau #8)

**Progress UI: Spinner simple accepté**
- **Justification**:
  - Create library: généralement < 30 secondes (SC-001: `< 30 seconds`), souvent beaucoup plus rapide
  - Adopt library: peut être plus long (baseline scan), mais c'est une opération ponctuelle
  - Spinner avec message "Création..." ou "Adoption en cours..." suffit
  - Pas besoin de progress détaillé pour ces opérations ponctuelles
  - **Note**: Si adoption prend > 10 secondes (grande bibliothèque), on peut afficher "Scan de X fichiers..." mais pas de progress bar détaillée nécessaire

---

### Slice UI #3: Sources + Détection + Import
**Ce que ça inclut**:
- Liste sources attachées (via `SourceAssociationManager.retrieveSources()`)
- Dialog attacher source (NSOpenPanel + validation, appel `SourceAssociationManager.attach()`)
- Bouton "Détecter" → appel `DetectionOrchestrator.executeDetection()` → affichage résultats
- Bouton "Importer" → appel `ImportExecutor.executeImport()` → affichage résultats

**Dépendances**:
- Mapping sourceId (drapeau #6)
- Progress UI (drapeau #1 — **spinner simple pour Slice #3 aussi acceptable pour P1**)
- Appel direct au core: `SourceAssociationManager.retrieveSources()`, `DetectionOrchestrator.executeDetection()`, `ImportExecutor.executeImport()`
- Gestion "no detection result" pour import

**Risques**: Progress/cancel (drapeau #1), import sans détection (drapeau #7)

**Progress UI: Spinner simple acceptable pour P1**
- **Justification**:
  - Pour Slice #3 (P1), un spinner simple avec message "Détection en cours..." ou "Import en cours..." est acceptable
  - Le core n'a pas d'API progress (drapeau #1), donc progress détaillé nécessiterait soit wrapper CLI (fragile), soit ajouter API au core (hors scope P1)
  - **Note**: Pour itérations futures, ajouter API progress au core pour afficher "X/Y items" serait souhaitable, mais pas bloquant pour P1

---

## 5. Core Readiness (check rapide)

### Output JSON: **OUI**
**Commandes concernées**: `library create/list/open/adopt`, `source attach/list`, `detect`, `import`, `status`, `index hash`  
**Format**: Toutes supportent `--json` avec structures bien définies dans `OutputFormatting.swift`. JSONEncoder avec `.prettyPrinted` et `.sortedKeys`.

### Reports/Audit: **OUI**
**Où stocké**: 
- Detection: `.mediahub/sources/{sourceId}/detections/{timestamp}.json`
- Import: `.mediahub/sources/{sourceId}/imports/{timestamp}.json`
**Format**: JSON avec schémas définis dans `DetectionResult` et `ImportResult`. `DetectionResultRetriever` et `ImportResultRetriever` permettent de lire l'historique.

### Progress/Cancel: **UNKNOWN**
**Progress**: Le CLI a `ProgressIndicator` (écrit sur stderr) mais le core n'expose pas d'API de progression en temps réel. Pas de callback `(Int, Int) -> Void` dans `DetectionOrchestrator` ou `ImportExecutor`.  
**Cancel**: SIGINT handler dans CLI (`ImportCommand.swift` ligne 173-182) mais pas d'API cancellation dans le core. L'UI devra soit wrapper CLI (fragile), soit ajouter API au core.

### Permissions macOS (volumes, sandbox): **RISQUE OUI**
**Pourquoi**: 
- `LibraryDiscoverer.discoverAll()` scanne les volumes montés (`/Volumes/*`)
- macOS App Sandbox bloque l'accès aux volumes externes sans permission
- L'app devra demander permissions via `NSOpenPanel` (user-initiated) ou entitlements (`com.apple.security.files.user-selected.read-write`)
- Le core détecte les erreurs (`PermissionErrorHandler`) mais l'UI devra gérer la demande de permission

**Vérification**: Vérifier `Package.swift` ou `Info.plist` de `MediaHubUI` pour entitlements. Tester accès volume externe.

---

## 6. Recommandation immédiate (5 actions max)

### 1. **Configurer la dépendance UI→Core**
**Action**: Ajouter `MediaHub` comme dépendance dans `MediaHubUI` (via `Package.swift` local path ou git). L'UI appellera le core directement, pas le CLI.  
**Pourquoi**: 
  - `Package.swift` expose déjà `MediaHub` comme library
  - Évite parsing JSON fragile, donne accès aux types Swift natifs
  - Plus performant, meilleure gestion d'erreurs
  - Aligné avec "UI never implements business logic" — l'UI orchestre via le core
  - `CLI_UI_MAPPING.md` définit la sémantique (équivalence), pas l'implémentation (appel CLI)  
**Comment**: 
  - Modifier la structure pour que `MediaHubUI` soit un target dans le même `Package.swift`, ou
  - Ajouter `MediaHub` comme dépendance locale dans un `Package.swift` séparé pour `MediaHubUI`
  - Documenter les APIs core à utiliser: `LibraryDiscoverer.discoverAll()`, `LibraryContext.openLibrary()`, `DetectionOrchestrator.executeDetection()`, etc.

### 2. **Clarifier la navigation selon IA_MAP_V1.md**
**Action**: Suivre `IA_MAP_V1.md` (source de vérité) pour la navigation: "No tabs visible by default", "one library, one surface", progressive disclosure. Le brainstorm peut servir d'inspiration mais n'est pas contractuel.  
**Pourquoi**: `IA_MAP_V1.md` est la source de vérité contractuelle. L'UI doit respecter "No tabs visible by default" et "progressive disclosure".  
**Comment**: Implémenter selon `IA_MAP_V1.md`. Le brainstorm peut donner des idées mais ne doit pas dicter la structure.

### 3. **Prototyper l'accès permissions macOS**
**Action**: Créer un test minimal SwiftUI qui demande accès à un volume externe via `NSOpenPanel` et vérifie les entitlements nécessaires.  
**Pourquoi**: Bloqueur potentiel si l'app ne peut pas accéder aux volumes. Mieux vaut valider tôt.  
**Comment**: Test dans `MediaHubUI` avec `NSOpenPanel` + vérifier `Info.plist` entitlements.

### 4. **API Progress/Cancel minimum pour vraie UX**
**Action**: Ajouter API progress/cancel minimale au core pour détection, import, et hash maintenance.  
**Pourquoi**: Pour une vraie UX (pas juste spinner), l'UI doit afficher progression réelle (X/Y items) et permettre cancellation.  
**Minimum requis** (pseudo-signatures):
- Types: `ProgressUpdate` (stage, current, total, message), `CancellationToken` (thread-safe), `CancellationError`
- Signatures modifiées: Ajouter `progress: ProgressCallback? = nil, cancellationToken: CancellationToken? = nil` à `DetectionOrchestrator.executeDetection()`, `ImportExecutor.executeImport()`, `HashCoverageMaintenance.computeMissingHashes()`
- Points d'injection: Dans boucles principales (comparaison items, import séquentiel, hash computation) — check cancellation + call progress périodiquement (throttling: max 1x/seconde)
- **Détails d'implémentation**: À documenter dans Phase 2 (ADR ou spec dédiée)

**Comment**: 
  - Ajouter types dans `Sources/MediaHub/` (nouveau fichier `Progress.swift`)
  - Modifier signatures dans `DetectionOrchestration.swift`, `ImportExecution.swift`, `HashCoverageMaintenance.swift`
  - Injecter appels progress/cancel dans les boucles principales
  - Documenter dans ADR

### 5. **Valider le flow détection→import dans l'UI**
**Action**: Documenter le flow exact: source attach → detect → (afficher résultats) → import. Gérer le cas "no detection result".  
**Pourquoi**: L'import dépend d'une détection préalable. L'UI doit gérer ce flow et les erreurs (pas de détection, détection échouée).  
**Comment**: Créer un diagramme de flow ou liste d'états (source attaché → détection disponible → import disponible).

---

## 7. API Progress/Cancel Minimum (pour vraie UX)

**Minimum requis**: 
- **Types**: `ProgressUpdate` (stage, current, total, message), `CancellationToken` (thread-safe), `CancellationError`
- **Signatures modifiées**: Ajouter `progress: ProgressCallback? = nil, cancellationToken: CancellationToken? = nil` à `DetectionOrchestrator.executeDetection()`, `ImportExecutor.executeImport()`, `HashCoverageMaintenance.computeMissingHashes()`
- **Points d'injection**: Dans boucles principales (comparaison items, import séquentiel, hash computation) — check cancellation + call progress périodiquement (throttling: max 1x/seconde)
- **Complexité**: Faible (optionnel, zero overhead si `nil`)

---

## Notes finales

- **Ne pas coder l'UI d'opérations longues** (detect/import/hash) avant d'avoir résolu le drapeau #1 (progress/cancel API). **Mais** UI Shell + discovery + adopt/create peuvent démarrer avec spinner simple (Slice #1-2).
- **Ne pas coder l'UI avant** d'avoir résolu les drapeaux #2 (filtrage média — **REQUIREMENT v1**), #3 (statistiques — **REQUIREMENT v1**), #4 (permissions), et #8 (confirmation).
- Le core est **prêt pour l'UI** côté données (JSON, reports), mais manque d'APIs interactives (progress, cancel) et de **requirements v1 obligatoires** (filtrage média, statistiques).
- **Source de vérité**: `UI_VISION.md` + `IA_MAP_V1.md` + `CLI_UI_MAPPING.md`. Le document `ui-design-proposal.md` est un brainstorm non contractuel qui peut servir d'inspiration mais ne doit pas dicter l'implémentation.
- **Requirements v1 obligatoires identifiés**:
  - **Drapeau #2**: Filtrage par type média (Images/Vidéos/Les deux) — PERSISTANT par source — nécessite changements CORE/CLI
  - **Drapeau #3**: Statistiques bibliothèque (total, répartition année/type) — fonctionnelles, pas décoratives — nécessite changements CORE/CLI
