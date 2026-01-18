# Review Report: Slice 16 - UI Hash Maintenance + Coverage

**Date**: 2026-01-17  
**Reviewer**: AI Assistant  
**Status**: ⚠️ **BLOCKING ISSUES FOUND**

---

## Executive Summary

Review complète de Slice 16 révèle **3 problèmes bloquants** dans l'implémentation de T-001:

1. **SCOPE CREEP**: Modification de fichiers non listés dans "Expected Files Touched"
2. **INCOHÉRENCE SPEC/TASK**: La spec dit que `hashCoverage` est "already available from Slice 9" mais il n'existe pas
3. **AFFICHAGE INCOMPLET**: Le task demande d'afficher "Entries missing hash count" mais ce n'est pas affiché explicitement

**Décision**: ❌ **KO** - Corrections nécessaires avant de continuer

---

## 1. Vérification des API Core

### ✅ API Core Existantes

**HashCoverageMaintenance**:
- ✅ `selectCandidates(libraryRoot:limit:fileManager:) throws -> HashCoverageCandidates`
  - Signature correcte, `fileManager` optionnel avec default
- ✅ `computeMissingHashes(libraryRoot:limit:fileManager:progress:cancellationToken:) throws -> HashComputationResult`
  - Signature correcte, tous les paramètres optionnels avec defaults

**DuplicateReporting**:
- ✅ `analyzeDuplicates(in:) throws -> ([DuplicateGroup], DuplicateSummary)`
  - Signature correcte

### ✅ Types de Retour Existants

- ✅ `HashCoverageCandidates` (struct)
- ✅ `HashComputationResult` (struct)
- ✅ `DuplicateGroup` (struct)
- ✅ `DuplicateSummary` (struct)
- ✅ `CancellationToken` (class)
- ✅ `ProgressUpdate` (struct)

**Conclusion**: Toutes les API Core référencées dans la spec existent et ont les bonnes signatures.

---

## 2. Problèmes Identifiés dans T-001

### ❌ PROBLÈME 1: Scope Creep

**Task T-001 dit**:
```
Expected Files Touched:
- Sources/MediaHubUI/StatusView.swift (update)
```

**Fichiers modifiés**:
- ✅ `Sources/MediaHubUI/StatusView.swift` (correct)
- ❌ `Sources/MediaHubUI/LibraryStatus.swift` (NON LISTÉ)
- ❌ `Sources/MediaHubUI/LibraryStatusService.swift` (NON LISTÉ)

**Pourquoi c'est un problème**:
- Violation de la règle "Scope Containment" (impl_review.mdc)
- Les tasks doivent respecter strictement "Expected Files Touched"
- Modifications en dehors du scope peuvent affecter d'autres fonctionnalités

**Correction nécessaire**:
- Option A: Mettre à jour "Expected Files Touched" dans tasks.md pour inclure LibraryStatus.swift et LibraryStatusService.swift
- Option B: Trouver un moyen d'implémenter T-001 sans modifier ces fichiers (mais impossible car hashCoverage n'existe pas)

### ⚠️ PROBLÈME 2: Incohérence Spec/Task

**Spec dit** (API-006, ligne 203):
> Display hash coverage statistics from `LibraryStatus` (already available from Slice 9)`

**Task T-001 dit** (ligne 39):
> Extract hash coverage data from `LibraryStatus.hashCoverage` (already available from Slice 9)

**Réalité**:
- `LibraryStatus` actuel (Slice 11) n'a PAS de propriété `hashCoverage`
- La spec assume que `hashCoverage` existe déjà, mais ce n'est pas le cas

**Pourquoi c'est un problème**:
- Incohérence entre spec/task et code existant
- Le task ne peut pas être complété sans modifier LibraryStatus (scope creep)
- La spec devrait être corrigée pour refléter la réalité

**Correction nécessaire**:
- Mettre à jour la spec pour indiquer que `hashCoverage` doit être ajouté à `LibraryStatus` dans T-001
- OU créer un task préalable pour ajouter `hashCoverage` à `LibraryStatus`

### ⚠️ PROBLÈME 3: Affichage Incomplet

**Task T-001 dit** (lignes 34-38):
```
2. Add hash coverage section to display:
   - Hash coverage percentage (e.g., "75% coverage")
   - Total entries count
   - Entries with hash count
   - Entries missing hash count
```

**Implémentation actuelle** (StatusView.swift, ligne 50):
```swift
Text("Hash coverage: \(percentage)% (\(hashCoverage.entriesWithHash) / \(hashCoverage.totalEntries) entries)")
```

**Problème**:
- ✅ Pourcentage affiché
- ✅ Total entries affiché (via totalEntries)
- ✅ Entries with hash affiché (via entriesWithHash)
- ❌ **Entries missing hash count NON AFFICHÉ EXPLICITEMENT**

Le task demande explicitement d'afficher "Entries missing hash count" mais l'implémentation ne l'affiche pas. On peut le calculer (totalEntries - entriesWithHash) mais ce n'est pas affiché.

**Correction nécessaire**:
- Ajouter l'affichage explicite de "Entries missing hash count" dans StatusView

---

## 3. Vérification des Signatures API vs Tasks

### T-004: Hash Maintenance Preview Orchestration

**Task dit** (ligne 118):
```
Call HashCoverageMaintenance.selectCandidates(libraryRoot:limit:) off MainActor
```

**API réelle**:
```swift
selectCandidates(libraryRoot:limit:fileManager:) throws -> HashCoverageCandidates
```

**Verdict**: ✅ OK - `fileManager` est optionnel avec default, peut être omis

### T-005: Hash Maintenance Execution Orchestration

**Task dit** (ligne 140):
```
Call HashCoverageMaintenance.computeMissingHashes(libraryRoot:limit:progress:cancellationToken:)
```

**API réelle**:
```swift
computeMissingHashes(libraryRoot:limit:fileManager:progress:cancellationToken:) throws -> HashComputationResult
```

**Verdict**: ✅ OK - `fileManager` est optionnel avec default, peut être omis

### T-015: Duplicate Detection Orchestrator

**Task dit** (ligne 416):
```
Call DuplicateReporting.analyzeDuplicates(in: libraryRoot)
```

**API réelle**:
```swift
analyzeDuplicates(in:) throws -> ([DuplicateGroup], DuplicateSummary)
```

**Verdict**: ✅ OK - Signature exacte

---

## 4. Incohérences Spec/Plan/Tasks

### Incohérence: Hash Coverage dans LibraryStatus

**Spec** (API-006, ligne 203):
> Display hash coverage statistics from `LibraryStatus` (already available from Slice 9)

**Plan** (Phase 1, ligne 238):
> Integrate with existing `LibraryStatus` from Slice 9 (hash coverage already available)

**Réalité**:
- `LibraryStatus` de Slice 11 n'a PAS de propriété `hashCoverage`
- La spec/plan assume que c'est déjà là, mais ce n'est pas le cas

**Impact**: T-001 ne peut pas être complété sans modifier LibraryStatus (scope creep)

---

## 5. Recommandations

### Correction Immédiate (T-001)

1. **Mettre à jour tasks.md**:
   - Ajouter `LibraryStatus.swift` et `LibraryStatusService.swift` à "Expected Files Touched" de T-001
   - OU créer un task préalable T-000 pour ajouter `hashCoverage` à `LibraryStatus`

2. **Corriger StatusView.swift**:
   - Ajouter l'affichage explicite de "Entries missing hash count"
   - Format suggéré: "Hash coverage: 75% (7500 with hash, 2500 missing hash / 10000 total entries)"

3. **Mettre à jour spec.md**:
   - Corriger API-006 pour indiquer que `hashCoverage` doit être ajouté à `LibraryStatus` dans T-001
   - OU documenter que `hashCoverage` n'existe pas encore et doit être ajouté

### Vérifications Futures

- Vérifier que tous les tasks suivants (T-002 à T-020) sont cohérents avec les API Core
- Vérifier que les types référencés dans les tasks existent
- Vérifier que les signatures API correspondent aux appels dans les tasks

---

## 6. Décision Finale

**Décision**: ❌ **KO**

**Raisons**:
1. Scope creep (fichiers modifiés non listés)
2. Incohérence spec/task (hashCoverage n'existe pas)
3. Affichage incomplet (entries missing hash non affiché)

**Actions Correctives**:
1. Mettre à jour tasks.md pour inclure LibraryStatus.swift et LibraryStatusService.swift dans T-001
2. Corriger StatusView.swift pour afficher explicitement "Entries missing hash count"
3. Mettre à jour spec.md pour refléter que hashCoverage doit être ajouté

**Une fois corrigé**: Re-review T-001 avant de continuer avec T-002

---

## 7. Points Positifs

- ✅ Toutes les API Core existent et ont les bonnes signatures
- ✅ Les types de retour existent
- ✅ L'implémentation de base est correcte (affichage du pourcentage et des comptes)
- ✅ La gestion de graceful degradation est correcte (affiche "N/A" quand hashCoverage est nil)
- ✅ Le code compile sans erreurs

---

**End of Review Report**
