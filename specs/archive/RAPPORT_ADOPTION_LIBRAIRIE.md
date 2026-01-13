# Rapport d'État des Lieux et d'Alignement : Adoption d'une Librairie Existante

**Date**: 2026-01-27  
**Agent**: Senior Swift / Spec-Kit / Safety-first  
**Objectif**: Analyser la compatibilité de MediaHub avec l'adoption d'une librairie existante organisée en YYYY/MM

---

## A) Résumé Exécutif

**Verdict**: **PARTIELLEMENT COMPATIBLE** — L'architecture actuelle supporte partiellement l'adoption, mais nécessite un réalignement minimal avant le Slice 6.

**Synthèse**:
- ✅ L'architecture core supporte l'adoption : `LibraryContentQuery` scanne tous les fichiers média existants, la structure minimum (`.mediahub/library.json`) n'exige pas une library vide, et `LegacyLibraryAdopter` démontre le pattern d'adoption.
- ⚠️ **Contradiction principale** : `LibraryOpener.openLibrary()` exige `.mediahub/library.json` existant. Une librairie existante sans métadonnées MediaHub ne peut pas être ouverte directement.
- ⚠️ **Gap fonctionnel** : Aucune commande CLI/API dédiée pour "adopter" une librairie existante (créer uniquement `.mediahub/` sans toucher aux médias).
- ✅ Les mécanismes de sécurité (dry-run, no-touch, idempotence) sont compatibles avec l'adoption.

**Recommandation** : Ré-alignement minimal requis — ajouter une commande `library adopt` (ou étendre `library create` avec flag `--adopt`) qui crée uniquement `.mediahub/` sans validation de dossier vide.

---

## B) Invariants Existants qui SUPPORTENT l'Adoption

### B.1 Architecture Core

#### 1. Structure Minimum Permissive
- **Référence**: `docs/library-structure-specification.md` lignes 7-15
- **Invariant**: La structure minimum MediaHub est uniquement `.mediahub/library.json`. Aucune contrainte sur la présence de fichiers média à la racine.
- **Support**: ✅ Une librairie existante avec fichiers YYYY/MM peut coexister avec `.mediahub/` sans conflit.

#### 2. LibraryContentQuery : Scan Complet de la Library
- **Référence**: `Sources/MediaHub/LibraryComparison.swift` lignes 32-125
- **Fonction**: `LibraryContentQuery.scanLibraryContents()` scanne récursivement TOUS les fichiers média dans la library (excluant `.mediahub/`).
- **Support**: ✅ Détecte automatiquement tous les fichiers existants, permettant une baseline sans import préalable.

#### 3. Known-Items Tracking : Basé sur Source, Pas sur Library
- **Référence**: `Sources/MediaHub/KnownItemsTracking.swift` lignes 273-318
- **Fonction**: `KnownItemsTracker.recordImportedItems()` enregistre les items importés par source (path-based).
- **Support**: ✅ Le système ne suppose pas que tous les fichiers de la library ont été importés. Les fichiers existants ne sont pas dans known-items, mais `LibraryContentQuery` les détecte lors de la comparaison.

#### 4. Import : Copie Atomique, Pas de Modification de Fichiers Existants
- **Référence**: `Sources/MediaHub/ImportExecution.swift` lignes 182-268
- **Fonction**: `processImportItem()` utilise `AtomicFileCopier.copyAtomically()` et gère les collisions via `CollisionHandler`.
- **Support**: ✅ L'import ne modifie jamais les fichiers existants. Les collisions sont gérées par policy (rename/skip/error), préservant les fichiers existants.

#### 5. LegacyLibraryAdopter : Pattern d'Adoption Existant
- **Référence**: `Sources/MediaHub/LibraryOpening.swift` lignes 165-223
- **Fonction**: `LegacyLibraryAdopter.adopt()` crée `.mediahub/` et génère des métadonnées sans toucher aux médias existants.
- **Support**: ✅ Démontre que le pattern d'adoption est architecturalement supporté. Limitation : détecte uniquement des patterns legacy spécifiques (MediaVault).

### B.2 Spec-Kit (Constitution + Slices 1-5)

#### 6. Constitution 3.2 : Transparent Storage
- **Référence**: `CONSTITUTION.md` lignes 36-38
- **Principe**: "MediaHub must store all media files as normal files in standard folder structures on disk."
- **Support**: ✅ Compatible avec une librairie existante organisée en YYYY/MM — MediaHub n'impose pas de structure propriétaire.

#### 7. Constitution 3.3 : Safe Operations
- **Référence**: `CONSTITUTION.md` lignes 40-42
- **Principe**: "MediaHub must not perform destructive actions without explicit user confirmation."
- **Support**: ✅ L'adoption (création de `.mediahub/` uniquement) est non-destructive par définition.

#### 8. Constitution 4.1 : Data Safety
- **Référence**: `CONSTITUTION.md` lignes 58-63
- **Invariant**: "MediaHub must never move or delete source files without explicit user consent" et "MediaHub must preserve all original file data during import."
- **Support**: ✅ L'adoption ne touche pas aux médias. L'import copie (ne déplace pas) et préserve les originaux.

#### 9. Slice 1 FR-005a : Attach to Existing Libraries
- **Référence**: `specs/001-library-entity/spec.md` ligne 82
- **Requirement**: "MediaHub MUST be able to attach to (adopt) an existing library folder created by prior versions (e.g., MediaVault) without requiring re-import of existing media files."
- **Support**: ✅ Le requirement existe, mais l'implémentation actuelle (`LegacyLibraryAdopter`) est limitée aux patterns legacy détectés.

#### 10. Slice 5 : Dry-Run et Safety Features
- **Référence**: `specs/005-safety-features-dry-run/spec.md` lignes 10-30
- **Fonctionnalité**: Dry-run mode pour prévisualiser les imports sans modification.
- **Support**: ✅ Permet de tester l'adoption et les imports futurs en toute sécurité.

---

## C) Contradictions et Gaps

### C.1 Contradiction Majeure : Validation de Structure Exige `.mediahub/library.json`

**Problème**:
- **Code**: `Sources/MediaHub/LibraryOpening.swift` lignes 343-356
  ```swift
  // Step 1: Validate structure
  do {
      _ = try LibraryStructureValidator.validateStructure(at: libraryRootURL)
  } catch {
      // Check if it's a legacy library
      if LegacyLibraryDetector.detect(at: path) {
          // Adopt legacy library
          ...
      }
      throw LibraryOpeningError.structureInvalid
  }
  ```
- **Validation**: `Sources/MediaHub/LibraryStructure.swift` lignes 67-92
  - `validateStructure()` exige `.mediahub/` et `.mediahub/library.json` existants.
- **Impact**: Une librairie existante (ex: `/Volumes/Photos/Photos/Librairie_Amateur`) sans `.mediahub/library.json` ne peut pas être ouverte via `LibraryOpener.openLibrary()`.

**Spec-Kit**:
- `specs/001-library-entity/spec.md` FR-005a mentionne l'adoption, mais ne spécifie pas de commande dédiée pour une librairie "vierge" (non-legacy).

**Gap Fonctionnel**:
- Aucune commande CLI/API pour créer `.mediahub/` dans une librairie existante sans passer par `LegacyLibraryDetector` (qui ne détecte que MediaVault).

### C.2 Contradiction Mineure : LibraryCreation Valide les Dossiers Non-Vides

**Problème**:
- **Code**: `Sources/MediaHub/LibraryCreation.swift` lignes 72-124
  - `LibraryPathValidator.validatePath()` retourne `.nonEmpty` si le dossier contient des fichiers.
  - Le workflow demande confirmation pour les dossiers non-vides (ligne 336-350).
- **Impact**: Techniquement compatible (confirmation possible), mais le workflow UX suppose une création "from scratch" plutôt qu'une adoption explicite.

**Spec-Kit**:
- `specs/001-library-entity/spec.md` User Story 1, ligne 21 : "Given a user wants to create a library, When they specify a directory path that already contains files, Then MediaHub warns the user and requires confirmation before proceeding."
- **Note**: Le spec ne distingue pas entre "créer dans un dossier non-vide" et "adopter une librairie existante".

### C.3 Gap Conceptuel : Known-Items vs Baseline Scan

**Problème**:
- **Code**: `Sources/MediaHub/KnownItemsTracking.swift`
  - `KnownItemsTracker` enregistre uniquement les items importés depuis des sources (path-based, scoped to source).
  - `LibraryContentQuery.scanLibraryContents()` scanne tous les fichiers média dans la library.
- **Impact**: ✅ **Pas de contradiction** — Le système fonctionne correctement :
  - Lors de la détection, `DetectionOrchestrator` (ligne 70) appelle `LibraryContentQuery.scanLibraryContents()` pour obtenir tous les fichiers de la library.
  - Les fichiers existants sont comparés par path avec les candidats de la source.
  - Les fichiers déjà dans la library sont exclus comme "known" (via `LibraryItemComparator.compare()`).
- **Conclusion**: Le système ne suppose pas un import préalable. Le scan baseline fonctionne.

**Spec-Kit**:
- `specs/002-sources-import-detection/spec.md` FR-007 : "MediaHub MUST identify which candidate items are new relative to the Library."
- ✅ Implémenté via `LibraryContentQuery` + `LibraryItemComparator`.

### C.4 Gap Fonctionnel : Pas de Commande "Adopt" Dédiée

**Problème**:
- **Code**: Aucune commande CLI `library adopt` ou API `LibraryAdopter.adoptExistingLibrary()`.
- **Impact**: Pour adopter une librairie existante, l'utilisateur doit :
  1. Soit utiliser `library create` avec confirmation (workflow non-optimal).
  2. Soit espérer que `LegacyLibraryDetector` détecte la librairie (limité aux patterns MediaVault).

**Spec-Kit**:
- `specs/001-library-entity/spec.md` FR-005a mentionne l'adoption, mais aucune spec ne définit une commande dédiée pour une librairie "vierge" (non-legacy, juste organisée en YYYY/MM).

### C.5 Vérification : Import Ne Modifie Pas les Fichiers Existants

**Vérification**:
- **Code**: `Sources/MediaHub/ImportExecution.swift` lignes 240-247
  ```swift
  // Copy file atomically (only in non-dry-run mode)
  do {
      let sourceURL = URL(fileURLWithPath: item.path)
      _ = try AtomicFileCopier.copyAtomically(
          from: sourceURL,
          to: finalDestinationURL,
          fileOperations: fileOperations
      )
  ```
- **Collision Handling**: `Sources/MediaHub/CollisionHandling.swift` (via `CollisionHandler.handleCollision()`)
  - Policy "skip" : ne copie pas si collision.
  - Policy "rename" : génère un nouveau nom, ne modifie pas l'existant.
  - Policy "error" : échoue, ne modifie pas l'existant.
- **Conclusion**: ✅ **Pas de contradiction** — L'import ne modifie jamais les fichiers existants. Les collisions sont gérées de manière sûre.

**Spec-Kit**:
- `specs/003-import-execution-media-organization/spec.md` FR-002 : "MediaHub MUST copy files from Source to Library (never move or modify Source files)."
- ✅ Implémenté correctement.

---

## D) Recommandation

### D.1 Verdict

**"Ré-alignement requis avant Slice 6"** — Correction minimale nécessaire.

### D.2 Correction Minimale Proposée

#### Option A : Commande CLI Dédiée (Recommandée)

**Ajout** : Nouvelle commande `mediahub library adopt <path>`

**Comportement**:
1. Vérifie que le chemin existe et est un dossier.
2. Vérifie que `.mediahub/library.json` n'existe pas déjà (sinon, propose d'ouvrir).
3. Crée uniquement `.mediahub/` et `library.json` (même logique que `LegacyLibraryAdopter.adopt()`, sans détection legacy).
4. Ne modifie aucun fichier média existant.
5. Supporte `--dry-run` pour prévisualiser.

**Fichiers à Modifier**:
- `Sources/MediaHubCLI/LibraryCommand.swift` : Ajouter sous-commande `adopt`.
- Optionnel : Extraire la logique d'adoption dans `Sources/MediaHub/LibraryAdoption.swift` (réutilisable par CLI et API).

**Avantages**:
- ✅ Workflow explicite et clair pour l'utilisateur.
- ✅ Séparation claire entre "create" (nouvelle library) et "adopt" (library existante).
- ✅ Compatible avec dry-run et safety features.

#### Option B : Extension de `library create` (Alternative)

**Modification** : Ajouter flag `--adopt` à `mediahub library create <path> --adopt`

**Comportement**:
- Si `--adopt` est présent, saute la validation de dossier vide et crée directement `.mediahub/`.
- Sinon, comportement actuel (validation + confirmation si non-vide).

**Fichiers à Modifier**:
- `Sources/MediaHubCLI/LibraryCommand.swift` : Ajouter flag `--adopt`.
- `Sources/MediaHub/LibraryCreation.swift` : Ajouter paramètre `adoptMode: Bool` à `LibraryCreator.createLibrary()`.

**Avantages**:
- ✅ Moins de code (réutilise workflow existant).
- ⚠️ Moins explicite (mélange création et adoption).

### D.3 Pourquoi Cette Correction Est Minimale

1. **Pas de changement d'architecture** : Utilise les mécanismes existants (`LibraryStructureCreator`, `LibraryMetadata`, etc.).
2. **Pas de modification des invariants** : Respecte Constitution 3.3 (Safe Operations) et 4.1 (Data Safety).
3. **Pas de modification du core import/detection** : Ces systèmes fonctionnent déjà avec des fichiers existants.
4. **Backward compatible** : N'affecte pas les workflows existants (`library create`, `library open`).

### D.4 Ce Qui Ne Doit PAS Être Modifié

- ❌ **Ne pas modifier** `LibraryContentQuery` — fonctionne déjà correctement.
- ❌ **Ne pas modifier** `ImportExecution` — gère déjà les collisions de manière sûre.
- ❌ **Ne pas modifier** `KnownItemsTracking` — le système de baseline scan fonctionne.
- ❌ **Ne pas modifier** les validations de structure — elles restent nécessaires pour l'ouverture normale.

---

## E) Proposition de Cadrage Minimal pour Slice 6

### E.1 Commandes Envisagées

**Commande principale** : `mediahub library adopt <path> [--dry-run]`

**Comportement**:
- Crée uniquement `.mediahub/library.json` dans une librairie existante.
- Ne modifie aucun fichier média.
- Supporte `--dry-run` pour prévisualiser la création de métadonnées.

**Commande secondaire** (optionnelle) : `mediahub library index <path> [--dry-run]`

- Scanne tous les fichiers média existants et crée un index baseline (hash/empreinte) dans `.mediahub/registry/index.json`.
- Permet une détection future plus rapide (P2) et une déduplication cross-source (P2).
- Pour P1, peut être un simple scan qui liste les fichiers (pas de hash nécessaire, `LibraryContentQuery` suffit).

### E.2 Garanties de Sécurité

1. **Dry-Run Obligatoire** : `--dry-run` prévisualise toutes les écritures (métadonnées uniquement).
2. **Confirmation Explicite** : Prompt de confirmation avant création de `.mediahub/` (sauf avec `--yes` pour scripting).
3. **Écritures Limitées** : Seule écriture = `.mediahub/library.json` (et éventuellement `.mediahub/registry/index.json` pour index baseline).
4. **No-Touch Garanti** : Aucun fichier média n'est modifié, renommé, déplacé, ou supprimé.
5. **Idempotence** : Si `.mediahub/library.json` existe déjà, proposer d'ouvrir plutôt que de ré-adopter.

### E.3 Stratégie d'Index (Baseline)

**Pour P1 (Minimal)**:
- Pas d'index hash nécessaire — `LibraryContentQuery.scanLibraryContents()` suffit pour la détection.
- Optionnel : Créer `.mediahub/registry/index.json` avec liste des chemins relatifs des fichiers média (baseline simple).

**Pour P2 (Futur)**:
- Index avec hash/empreinte (SHA-256) pour déduplication cross-source.
- Index incrémental (mise à jour lors des imports, pas re-scan complet).

**Format Baseline P1 (exemple)**:
```json
{
  "version": "1.0",
  "createdAt": "2026-01-27T10:00:00Z",
  "baseline": [
    {
      "relativePath": "2024/01/image1.jpg",
      "size": 1234567,
      "modifiedAt": "2024-01-15T12:00:00Z"
    }
  ]
}
```

**Note** : Pour P1, cet index est optionnel. Le scan runtime via `LibraryContentQuery` fonctionne déjà.

### E.4 Intégration avec Import Futur

**Idempotence** :
- Lors de l'import depuis une source, `DetectionOrchestrator` compare les candidats avec `LibraryContentQuery.scanLibraryContents()`.
- Les fichiers déjà présents (même path) sont exclus comme "known".
- ✅ **Déjà fonctionnel** — Aucun changement nécessaire.

**Collision Handling** :
- Si un import tente de copier un fichier qui existe déjà au même path, `CollisionHandler` applique la policy (rename/skip/error).
- ✅ **Déjà fonctionnel** — Aucun changement nécessaire.

---

## F) Références Exactes

### F.1 Code

- `Sources/MediaHub/LibraryOpening.swift` : lignes 343-356 (validation structure)
- `Sources/MediaHub/LibraryStructure.swift` : lignes 67-92 (validateStructure)
- `Sources/MediaHub/LibraryCreation.swift` : lignes 72-124 (validation path non-vide)
- `Sources/MediaHub/LibraryComparison.swift` : lignes 32-125 (scanLibraryContents)
- `Sources/MediaHub/LibraryOpening.swift` : lignes 165-223 (LegacyLibraryAdopter)
- `Sources/MediaHub/ImportExecution.swift` : lignes 240-247 (copie atomique)
- `Sources/MediaHub/KnownItemsTracking.swift` : lignes 273-318 (recordImportedItems)

### F.2 Spec-Kit

- `CONSTITUTION.md` : lignes 36-38 (Transparent Storage), 40-42 (Safe Operations), 58-63 (Data Safety)
- `specs/001-library-entity/spec.md` : ligne 82 (FR-005a)
- `specs/002-sources-import-detection/spec.md` : FR-007 (identify new items)
- `specs/003-import-execution-media-organization/spec.md` : FR-002 (copy, never move)
- `specs/005-safety-features-dry-run/spec.md` : lignes 10-30 (dry-run mode)
- `docs/library-structure-specification.md` : lignes 7-15 (structure minimum)

---

## G) Conclusion

MediaHub est **architecturalement compatible** avec l'adoption d'une librairie existante. Les mécanismes core (scan de library, import idempotent, collision handling) fonctionnent déjà avec des fichiers existants.

**Le seul gap** est l'absence d'une commande explicite pour créer `.mediahub/` dans une librairie existante sans passer par la détection legacy (limitée).

**Recommandation finale** : Implémenter `mediahub library adopt <path>` dans le Slice 6, avec support dry-run et confirmation. Cette addition minimale permet d'adopter une librairie existante de manière explicite et sûre, sans modifier l'architecture core.

---

**Rapport généré le**: 2026-01-27  
**Statut**: Prêt pour décision Slice 6
