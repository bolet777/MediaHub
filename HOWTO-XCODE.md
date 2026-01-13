# HOWTO-XCODE

## 0. Résumé du repo (SPM + CLI + future UI)

### Package Swift
- **Swift tools version** : 5.9
- **Platforms** : macOS 13+ (.macOS(.v13))
- **Products** :
  - `MediaHub` (library) — Core logique métier
  - `mediahub` (executable) — CLI tool
- **Targets** :
  - `MediaHub` (target library) — Logique métier UI-agnostic (Library, Source, Import, Detection, Tracking)
  - `MediaHubCLI` (target executable) — Thin wrapper CLI (ArgumentParser, commandes, formatters, progress)
  - `MediaHubTests` (target test) — Tests unitaires et d'intégration (100+ tests)
- **Dépendances externes** :
  - `swift-argument-parser` (1.2.0+) — CLI parsing (utilisé par MediaHubCLI uniquement)

### Entry point CLI
- `Sources/MediaHubCLI/main.swift` : Point d'entrée simple
- `MediaHubCommand` (struct ParsableCommand) avec subcommands : `library`, `source`, `detect`, `import`, `status`
- CLI = thin wrapper qui appelle MediaHub (Core)

### Spec-Kit
- **Où** : `specs/` (001-library-entity, 002-sources-import-detection, 003-import-execution-media-organization, 004-cli-tool-packaging, 005-safety-features-dry-run)
- **Quoi** : Définition architecturale par "Slices" (bounded contexts)
- **Slices complétés** : 1–5 (frozen + validés)
- **Constitution** : `CONSTITUTION.md` définit les principes non-négociables (transparent storage, safe operations, deterministic behavior, interoperability first, scalability by design)
- **Mapping Slices → Targets** :
  - Slice 1 (Library Entity) → `Sources/MediaHub/Library*.swift`
  - Slice 2 (Sources & Detection) → `Sources/MediaHub/Source*.swift`, `DetectionOrchestration.swift`, `DetectionResult.swift`
  - Slice 3 (Import Execution) → `Sources/MediaHub/Import*.swift`, `KnownItemsTracking.swift`, `CollisionHandling.swift`, etc.
  - Slice 4 (CLI Tool) → `Sources/MediaHubCLI/`
  - Slice 5 (Safety Features) → Intégré dans CLI (dry-run, confirmation) + Core (read-only guarantees)

### Risques / Points d'attention
- **Architecture déjà saine** : Core est UI-agnostic, CLI est thin wrapper ✅
- **Pas de refactorisation majeure nécessaire** ✅
- **SwiftUI app pourra directement importer MediaHub** ✅
- **Attention** : Entitlements nécessaires pour accès fichiers (File Access, Full Disk Access si besoin)
- **Async/await** : Le Core utilise des APIs synchrones actuellement (pas de `async/await` dans MediaHub), donc intégration SwiftUI sera straightforward avec Task ou `.task {}`

---

## 1. Préparation en amont

### 1.1 Pré-requis

- **Xcode version conseillée (min)** : Xcode 15.0+ (pour Swift 5.9 et macOS 13 SDK)
- **macOS version** : macOS 13 Ventura ou plus récent (cible du package)
- **Command Line Tools** : Installer avec `xcode-select --install` si pas déjà fait

### 1.2 Santé du package

**Commandes de validation** (à exécuter dans `/Volumes/Photos/_DevTools/MediaHub/`) :

```bash
# 1. Build le package
swift build

# 2. Exécute les tests (100+ tests)
swift test

# 3. Exécute la CLI (smoke test)
swift run mediahub --help
```

**Résultats attendus** :
- `swift build` → `Build complete!` (ou similaire, pas d'erreurs de compilation)
- `swift test` → `Test Suite 'All tests' passed` (100+ tests passent)
- `swift run mediahub --help` → Affiche l'aide de la CLI (subcommands: library, source, detect, import, status)

**Quoi faire si ça échoue** :
- **Build échoue** : Vérifier la version de Swift (`swift --version` doit être 5.9+), nettoyer `.build/` (`rm -rf .build/`), rebuild
- **Tests échouent** : Lire le message d'erreur, vérifier que les fixtures de test sont présentes, exécuter un test isolé (`swift test --filter <TestName>`) pour debugger
- **CLI crash** : Vérifier les permissions d'accès fichiers (tester avec un répertoire dans `~/Desktop` pour éviter problèmes de permissions)

---

## 2. Ouvrir et utiliser le Package dans Xcode

### 2.1 Ouverture

**Comment ouvrir `Package.swift` dans Xcode** :

```bash
# Option 1 : Double-cliquer sur Package.swift dans Finder
open Package.swift

# Option 2 : Ouvrir depuis le terminal
cd /Volumes/Photos/_DevTools/MediaHub
open Package.swift

# Option 3 : File > Open dans Xcode, sélectionner Package.swift
```

**Pièges fréquents** :
- **Indexation lente** : Xcode indexe le package et les dépendances (swift-argument-parser). Attendre la fin (barre de progression en haut). Si bloqué >5 min, relancer Xcode.
- **Caches corrompus** : Si Xcode ne résout pas les dépendances ou affiche des erreurs fantômes, nettoyer :
  - `File > Close Workspace` puis réouvrir
  - Quitter Xcode, supprimer `.build/` et `~/Library/Developer/Xcode/DerivedData/MediaHub-*/`, réouvrir
  - `Product > Clean Build Folder` (Cmd+Shift+K)
- **DerivedData bloat** : Si build lent ou erreurs de cache, supprimer le répertoire DerivedData spécifique au projet dans `~/Library/Developer/Xcode/DerivedData/`

### 2.2 Schemes & Run

**Quel scheme choisir pour exécuter la CLI** :
- Scheme `mediahub` (executable) → Exécute la CLI

**Comment passer des arguments à la CLI dans Xcode** :
1. Sélectionner le scheme `mediahub` dans la barre du haut (à gauche du bouton Play/Run)
2. `Product > Scheme > Edit Scheme...` (ou cliquer sur le scheme et choisir "Edit Scheme")
3. Onglet `Run` (à gauche) → Section `Arguments` (onglet en haut)
4. `Arguments Passed On Launch` → Ajouter les arguments ligne par ligne
   - Exemple pour `mediahub library create /tmp/test-library` :
     ```
     library
     create
     /tmp/test-library
     ```
   - Exemple pour `mediahub status --library /path/to/library --json` :
     ```
     status
     --library
     /path/to/library
     --json
     ```
5. Cocher/décocher pour activer/désactiver des arguments sans les supprimer
6. Close → Cmd+R pour exécuter

**Où voir stdout/stderr** :
- Console Xcode (en bas, `View > Debug Area > Show Debug Area` ou Cmd+Shift+Y)
- Logs apparaissent en temps réel pendant l'exécution
- Si console cachée, ouvrir avec le bouton en bas à droite (icône console)

### 2.3 Debug

**Breakpoints** :
- Cliquer dans la gouttière (à gauche du numéro de ligne) pour ajouter un breakpoint
- Breakpoint bleu = actif, gris = désactivé
- Cmd+Y pour activer/désactiver tous les breakpoints
- Exécuter avec Cmd+R, le debugger s'arrête au breakpoint
- Controls : Continue (Cmd+Ctrl+Y), Step Over (F6), Step Into (F7), Step Out (F8)

**LLDB minimal utile** (console LLDB quand arrêté sur breakpoint) :
- `po <variable>` : Print object (affiche la variable)
- `p <expression>` : Évalue une expression Swift
- `frame variable` : Liste toutes les variables locales
- `bt` : Backtrace (call stack)
- `c` : Continue (reprend l'exécution)

**Tips Swift pour non-swift-dev** (utile pour debug) :
- **Optionals** : `String?` = peut être `nil`. Déballer avec `if let value = optionalValue { ... }` ou `guard let value = optionalValue else { return }`
- **Errors** : `throws` = fonction peut lever une erreur. Appeler avec `try`, gérer avec `do { try ... } catch { ... }`
- **Async/await** : Pas utilisé dans MediaHub actuellement (APIs synchrones), donc pas de souci
- **Structs vs Classes** : MediaHub utilise des structs (immutables par défaut, copy-on-write). Si variable en lecture seule, déclarer `var` localement pour débugger.
- **FileManager** : API Foundation pour accès fichiers. Paths en `String` ou `URL` (préférer `URL`).

**Debugging efficace** :
- Ajouter des breakpoints dans MediaHubCLI (ex: `ImportCommand.run()`) pour voir les arguments parsés
- Puis Step Into (F7) pour entrer dans MediaHub Core (ex: `ImportExecutor.executeImport()`)
- Inspecter les variables avec `po` dans la console LLDB

---

## 3. Structurer le code pour partager CLI et UI (aligné Spec-Kit)

### 3.1 Diagnostic actuel

**Où est la logique "Core" aujourd'hui** :
- ✅ **Déjà isolée dans `MediaHub` (target library)** : `Sources/MediaHub/`
- Contient toute la logique métier UI-agnostic :
  - Library management (création, ouverture, validation, discovery)
  - Source management (validation, scanning, association)
  - Detection (orchestration, comparaison, résultats)
  - Import (execution, collision handling, tracking)
  - Utilities (timestamp extraction, destination mapping, atomic copy)

**Ce qui est couplé à la CLI** (dans `MediaHubCLI`) :
- Parsing arguments (ArgumentParser)
- Console I/O (print, readLine, FileHandle.standardError)
- Progress indicators (ProgressIndicator.swift)
- Output formatting (JSON vs human-readable via OutputFormatting.swift)
- Error formatting pour CLI (ErrorFormatter)
- LibraryContext (helper pour résoudre MEDIAHUB_LIBRARY env var)

**Verdict** : Architecture déjà optimale pour UI. Pas de refactorisation nécessaire. ✅

### 3.2 Architecture cible

**Targets recommandées** (architecture déjà en place) :
- `MediaHub` (library) — Core logic, aucune dépendance CLI/UI
- `MediaHubCLI` (executable) — CLI wrapper (dépend de MediaHub + ArgumentParser)
- `MediaHubUI` (future app macOS) — SwiftUI app (dépendra de MediaHub uniquement, pas de MediaHubCLI)
- `MediaHubTests` (test) — Tests pour MediaHub + MediaHubCLI

**Règles de dépendances** :
```
MediaHubUI  →  MediaHub  ←  MediaHubCLI  ←  ArgumentParser
                   ↑
            MediaHubTests
```

- **MediaHub** : Ne dépend de rien d'externe (Foundation uniquement)
- **MediaHubCLI** : Dépend de MediaHub + ArgumentParser
- **MediaHubUI** : Dépendra de MediaHub uniquement (import MediaHub, pas MediaHubCLI)
- **Core ne dépend de rien de UI/CLI** : Respect total ✅

**Comment Spec-Kit/Slices se mappe à ces targets** :
- **Slices 1–3** (Library, Sources, Import) → `MediaHub` (Core)
- **Slice 4** (CLI Tool) → `MediaHubCLI`
- **Slice 5** (Safety Features) → Partagé (dry-run dans Core, confirmation dans CLI)
- **Future Slice UI** → `MediaHubUI` (nouvelle app)

### 3.3 Changements concrets (si nécessaires)

**Aucune modification nécessaire.** L'architecture actuelle est déjà prête pour l'UI. ✅

**Si vous vouliez ajouter des helpers partagés CLI/UI** (optionnel, futur) :
- Créer un target `MediaHubShared` pour code commun CLI/UI (ex: formatters, validation helpers)
- Mais pas nécessaire pour MVP UI : UI peut directement importer MediaHub

**Migration en petites étapes** :
- Étape 1 : Ouvrir le package dans Xcode (déjà fait)
- Étape 2 : Créer l'app macOS (voir section 4)
- Étape 3 : Importer MediaHub dans l'app
- Étape 4 : Appeler un use case existant (ex: LibraryCreator, LibraryOpener)
- Build vert à chaque étape ✅

---

## 4. Créer une app macOS qui consomme le package

### 4.1 Option A (préférée) : App macOS via Xcode + dépendance locale SPM

**Créer une app SwiftUI** :
1. `File > New > Project...`
2. Choisir `macOS` (onglet en haut) → `App` (template)
3. Cliquer `Next`
4. Configuration :
   - **Product Name** : `MediaHubUI` (ou nom de votre choix)
   - **Organization Identifier** : `com.yourdomain` (ex: `com.mediahub`)
   - **Bundle Identifier** : Auto-généré (ex: `com.mediahub.MediaHubUI`)
   - **Interface** : SwiftUI (par défaut)
   - **Language** : Swift
   - **Storage** : None (pas besoin de Core Data pour l'instant)
   - **Include Tests** : Cocher si vous voulez des tests UI
5. Cliquer `Next`
6. **Emplacement** : Choisir où sauvegarder l'app. **Recommandation** : Créer dans le repo MediaHub, dans un sous-dossier `MediaHubUI/` :
   ```
   /Volumes/Photos/_DevTools/MediaHub/MediaHubUI/
   ```
   Avantages :
   - Code versionné ensemble (git)
   - Facile de référencer le package local MediaHub
   - Un seul repo pour CLI + UI
7. **Add to** : Ne pas ajouter au workspace MediaHub (Package.swift) → Laisser vide ou créer un nouveau workspace
8. **Create Git repository** : Décocher si le repo MediaHub est déjà un repo git
9. Cliquer `Create`

**Ajouter le package local (MediaHub)** :
1. Ouvrir le projet MediaHubUI dans Xcode (si pas déjà ouvert)
2. Sélectionner le projet `MediaHubUI` dans le navigateur (à gauche)
3. Sélectionner le target `MediaHubUI` (sous `TARGETS`)
4. Onglet `General` → Section `Frameworks, Libraries, and Embedded Content`
5. Cliquer `+` (bouton en bas de la section)
6. Cliquer `Add Other...` → `Add Package Dependency...`
7. Dans la fenêtre :
   - **Search or Enter Package URL** : Cliquer sur `Add Local...` (en bas)
   - Naviguer vers `/Volumes/Photos/_DevTools/MediaHub/` (répertoire contenant Package.swift)
   - Cliquer `Add Package`
8. Xcode va résoudre le package
9. Dans la liste des produits, **cocher `MediaHub`** (library, pas `mediahub` executable)
10. Cliquer `Add Package`

**Importer MediaHub et appeler un use case existant** :
1. Ouvrir `ContentView.swift` (dans le navigateur MediaHubUI)
2. Ajouter `import MediaHub` en haut (après `import SwiftUI`)
3. Appeler un use case, par exemple créer une library :

```swift
import SwiftUI
import MediaHub

struct ContentView: View {
    @State private var libraryPath: String = ""
    @State private var statusMessage: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("MediaHub UI — MVP")
                .font(.largeTitle)

            TextField("Library Path", text: $libraryPath)
                .textFieldStyle(.roundedBorder)
                .frame(width: 400)

            Button("Create Library") {
                createLibrary(at: libraryPath)
            }

            Text(statusMessage)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 500, height: 300)
    }

    func createLibrary(at path: String) {
        let creator = LibraryCreator()

        creator.createLibrary(at: path) { result in
            switch result {
            case .success(let metadata):
                statusMessage = "Library created: \(metadata.libraryId)"
            case .failure(let error):
                statusMessage = "Error: \(error.localizedDescription)"
            }
        }
    }
}
```

4. Build (Cmd+B) et Run (Cmd+R)
5. Tester en entrant un chemin (ex: `/tmp/test-library-ui`) et cliquer "Create Library"

**Comment garder l'app dans le même repo ou dans un sous-dossier (reco + raisons)** :
- **Recommandation** : Garder dans un sous-dossier du repo MediaHub (`MediaHubUI/`)
- **Raisons** :
  - Versionning unifié (git commit CLI + UI ensemble)
  - Référence locale au package MediaHub (pas besoin de publier sur GitHub/registry)
  - Simplification du workflow de développement (un seul `git clone`, un seul repo)
  - Tests end-to-end CLI + UI dans le même repo
- **Alternative** : Repo séparé si vous voulez distribuer l'UI indépendamment de la CLI (plus tard), mais pour le développement initial, même repo est plus simple.

**Structure finale** :
```
MediaHub/
├── Package.swift
├── Sources/
│   ├── MediaHub/           # Core library
│   └── MediaHubCLI/        # CLI executable
├── Tests/
│   └── MediaHubTests/
├── MediaHubUI/             # App macOS SwiftUI (nouveau)
│   ├── MediaHubUI.xcodeproj
│   ├── MediaHubUI/
│   │   ├── ContentView.swift
│   │   ├── MediaHubUIApp.swift
│   │   └── Assets.xcassets
│   └── ...
├── docs/
├── specs/
└── ...
```

### 4.2 Option B : App macOS comme target SPM (si faisable)

**Verdict** : Pas recommandé pour une app macOS SwiftUI.

**Raisons** :
- SPM supporte les executables, mais pas les `.app` bundles avec assets, storyboards, Info.plist, signing, entitlements, etc.
- Xcode project est nécessaire pour :
  - Gérer les assets (icônes, images, couleurs)
  - Configurer signing & entitlements (obligatoire pour distribuer sur macOS)
  - Gérer l'Info.plist (permissions, identité de l'app)
  - Utiliser Xcode Previews pour SwiftUI (bien plus pratique qu'un executable SPM)
  - Débugger l'UI avec View Debugger, Instruments, etc.
- **Option B rejetée** : Utiliser Xcode project (Option A) pour l'app macOS.

---

## 5. UI SwiftUI : premier écran MVP relié au même chemin que la CLI

### Définir un "workflow" minimal identique à la CLI

**Commande CLI existante** : `mediahub library create <path>`

**Équivalent UI MVP** :
1. TextField pour saisir le chemin de la library
2. Button "Create Library"
3. Affichage du résultat (succès → library ID, échec → message d'erreur)

**Use case Core** : `LibraryCreator.createLibrary(at:completion:)`

### Design d'interface minimal (input → run → output)

```swift
import SwiftUI
import MediaHub

struct ContentView: View {
    @State private var libraryPath: String = ""
    @State private var statusMessage: String = ""
    @State private var isLoading: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Text("MediaHub — Create Library")
                .font(.title)

            HStack {
                TextField("Library Path (e.g., /Volumes/Photos/MyLibrary)", text: $libraryPath)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isLoading)

                Button("Browse...") {
                    selectFolder()
                }
                .disabled(isLoading)
            }
            .frame(width: 500)

            Button(action: createLibrary) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .frame(width: 20, height: 20)
                } else {
                    Text("Create Library")
                }
            }
            .disabled(libraryPath.isEmpty || isLoading)

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .foregroundColor(statusMessage.starts(with: "Error") ? .red : .green)
                    .padding()
                    .frame(maxWidth: 500)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }

            Spacer()
        }
        .padding()
        .frame(width: 600, height: 400)
    }

    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.title = "Select Library Location"

        if panel.runModal() == .OK {
            libraryPath = panel.url?.path ?? ""
        }
    }

    func createLibrary() {
        isLoading = true
        statusMessage = ""

        let creator = LibraryCreator()

        creator.createLibrary(at: libraryPath) { result in
            DispatchQueue.main.async {
                isLoading = false

                switch result {
                case .success(let metadata):
                    statusMessage = "Library created successfully!\nID: \(metadata.libraryId)"
                case .failure(let error):
                    statusMessage = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
```

### Gestion async, affichage logs, erreurs

**Async** :
- `LibraryCreator.createLibrary(at:completion:)` utilise un callback (completion handler)
- UI SwiftUI doit mettre à jour l'état sur le main thread : `DispatchQueue.main.async { ... }`
- Pour afficher un indicateur de chargement : `@State private var isLoading: Bool = false`

**Alternative moderne avec Task** :
Si vous voulez convertir les callbacks en async/await (futur) :
```swift
func createLibrary() async {
    isLoading = true
    statusMessage = ""

    do {
        let metadata = try await createLibraryAsync(at: libraryPath)
        statusMessage = "Library created!\nID: \(metadata.libraryId)"
    } catch {
        statusMessage = "Error: \(error.localizedDescription)"
    }

    isLoading = false
}

// Helper pour convertir completion handler en async/await
func createLibraryAsync(at path: String) async throws -> LibraryMetadata {
    return try await withCheckedThrowingContinuation { continuation in
        let creator = LibraryCreator()
        creator.createLibrary(at: path) { result in
            continuation.resume(with: result)
        }
    }
}
```

Puis appeler depuis l'UI :
```swift
Button("Create Library") {
    Task {
        await createLibrary()
    }
}
```

**Affichage logs** :
- Pour MVP : Afficher le résultat dans un `Text()` (comme ci-dessus)
- Pour debug : `print()` affichera dans la console Xcode
- Pour production : Logger avec `os.log` ou `Logger` (SwiftLog)

**Erreurs** :
- `LibraryCreationError` est déjà `LocalizedError` → `.localizedDescription` fonctionne
- Afficher en rouge avec `.foregroundColor(.red)`

### Previews + résolution des erreurs de previews

**Previews SwiftUI** :
```swift
#Preview {
    ContentView()
}
```

**Résolution des erreurs de previews** :
- **"Cannot preview in this file"** : Vérifier que `import SwiftUI` est présent, que le fichier compile sans erreurs
- **"Preview crashed"** : Fermer la preview, Clean Build Folder (Cmd+Shift+K), réouvrir la preview
- **"No such module 'MediaHub'"** : Vérifier que le package MediaHub est bien ajouté au target MediaHubUI (voir section 4.1)
- **Preview lent** : Normal pour la première fois (Xcode compile un executable de preview). Les previews suivantes seront plus rapides.
- **Preview bloquée** : `Editor > Canvas` pour activer/désactiver, ou relancer Xcode

**Tips** :
- Previews fonctionnent mieux avec des données mock/static pour éviter les side effects (création de fichiers, etc.)
- Pour tester la vraie logique, utiliser l'app (Cmd+R) plutôt que les previews

---

## 6. Permissions, Signing, Entitlements, Info.plist

### Ce qui est nécessaire selon les accès réels du produit

**MediaHub accède à** :
- Filesystem (lecture/écriture dans les libraries et sources)
- Potentiellement des volumes externes, network shares, etc.

**Permissions macOS nécessaires** :
- **File Access** : Lecture/écriture dans les dossiers choisis par l'utilisateur
- **Full Disk Access** (optionnel, si besoin d'accéder à des dossiers protégés comme `~/Library`, `/Volumes`, etc.)

### Où régler ça dans Xcode

**Signing** :
1. Sélectionner le projet MediaHubUI dans le navigateur
2. Sélectionner le target MediaHubUI
3. Onglet `Signing & Capabilities`
4. **Signing** :
   - **Automatically manage signing** : Cocher (recommandé pour développement)
   - **Team** : Sélectionner votre Apple Developer Team (ou "Personal Team" si développement local)
   - Xcode générera automatiquement un certificat de développement

**Entitlements** :
1. Dans `Signing & Capabilities`, cliquer `+ Capability`
2. Ajouter les capabilities nécessaires :
   - **App Sandbox** : Activé par défaut sur macOS (recommandé pour distribution)
   - **File Access** (dans App Sandbox) :
     - **User Selected File** : Read/Write (pour accéder aux fichiers/dossiers choisis par l'utilisateur via NSOpenPanel)
     - **Downloads Folder** : Read/Write (si besoin)
     - **Pictures Folder** : Read/Write (si besoin)
   - **Full Disk Access** : Pas une entitlement, doit être activé manuellement dans System Preferences > Privacy & Security > Full Disk Access (ajouter MediaHubUI.app)

**Fichier généré** : `MediaHubUI.entitlements` (créé automatiquement quand vous ajoutez des capabilities)

### Quelles clés Info.plist

**Info.plist** : Xcode gère automatiquement l'Info.plist pour SwiftUI apps (dans le target settings).

**Clés à ajouter** (si nécessaire) :
1. Sélectionner le projet MediaHubUI → Target MediaHubUI → Onglet `Info`
2. Cliquer `+` pour ajouter une clé
3. Clés utiles pour MediaHub :
   - **`NSDesktopFolderUsageDescription`** : "MediaHub needs access to your Desktop to manage media libraries."
   - **`NSDocumentsFolderUsageDescription`** : "MediaHub needs access to your Documents to manage media libraries."
   - **`NSDownloadsFolderUsageDescription`** : "MediaHub needs access to your Downloads to import media."
   - **`NSRemovableVolumesUsageDescription`** : "MediaHub needs access to external drives to manage media libraries."
   - **`NSNetworkVolumesUsageDescription`** : "MediaHub needs access to network drives to manage media libraries."

**Note** : Ces clés affichent un dialog de permission à l'utilisateur la première fois que l'app accède à ces dossiers.

### Sandbox macOS : implications

**App Sandbox** : Activé par défaut pour les apps macOS distribuées via Mac App Store ou notariées.

**Implications** :
- L'app ne peut accéder qu'aux fichiers/dossiers explicitement autorisés :
  - Fichiers choisis par l'utilisateur via NSOpenPanel/NSSavePanel (security-scoped bookmarks)
  - Dossiers avec entitlements (Downloads, Pictures, etc.)
- Pas d'accès libre au filesystem (sauf si Full Disk Access accordé manuellement par l'utilisateur dans System Preferences)

**Recommandation pour MediaHub** :
- Utiliser **User Selected File** (Read/Write) → L'utilisateur choisit le dossier de la library via NSOpenPanel → App a accès à ce dossier
- Pour les sources (ex: `/Volumes/Photos`), utiliser NSOpenPanel pour demander l'accès au dossier source
- Sauvegarder les security-scoped bookmarks pour accéder aux dossiers à nouveau (voir `URL.bookmarkData()` et `URL(resolvingBookmarkData:)`)

**Alternative** : Désactiver le sandbox pour développement (décocher `App Sandbox` dans Signing & Capabilities), mais l'app ne pourra pas être distribuée sur le Mac App Store ni notariée.

---

## 7. Packaging et exécution

### Debug vs Release

**Debug** (par défaut) :
- Build configuration : Debug
- Optimisations désactivées
- Symboles de debug inclus
- Assertions actives
- Plus lent, mais debuggable

**Release** :
- Build configuration : Release
- Optimisations activées
- Symboles de debug exclus (ou séparés en dSYM)
- Assertions désactivées
- Plus rapide, taille réduite

**Changer la configuration** :
1. `Product > Scheme > Edit Scheme...`
2. Onglet `Run` → `Info` → `Build Configuration` → Choisir `Debug` ou `Release`

### Notarization (si pertinent) : mention rapide + étapes de base

**Notarization** : Processus Apple pour valider qu'une app est sûre (pas de malware). Obligatoire pour distribuer une app en dehors du Mac App Store (téléchargement direct).

**Étapes de base** :
1. Signer l'app avec un Developer ID Application certificate (pas un Development certificate)
2. Archiver l'app (`Product > Archive`)
3. Exporter l'app avec l'option "Developer ID" (Xcode générera un fichier .app signé)
4. Créer un DMG ou ZIP de l'app
5. Soumettre à Apple pour notarization : `xcrun notarytool submit MediaHubUI.dmg --keychain-profile "AC_PASSWORD"`
6. Attendre la validation (quelques minutes)
7. Stapler le ticket de notarization au DMG : `xcrun stapler staple MediaHubUI.dmg`
8. Distribuer le DMG

**Ressources** :
- [Notarizing macOS Software Before Distribution](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)

### Distribution interne (zip/dmg) : mention rapide

**ZIP** :
- Archiver l'app : `Product > Archive` → `Distribute App` → `Copy App`
- Zipper le .app : `zip -r MediaHubUI.zip MediaHubUI.app`
- Distribuer le .zip

**DMG** (recommandé pour distribution propre) :
- Créer un DMG avec `hdiutil` ou un tool comme [create-dmg](https://github.com/create-dmg/create-dmg)
- Exemple : `create-dmg MediaHubUI.app` → Génère `MediaHubUI.dmg`

**Distribution interne** : Pas besoin de notarization si distribué uniquement dans votre équipe (les utilisateurs devront clic-droit > Ouvrir pour contourner Gatekeeper).

---

## 8. Checklist finale

- [ ] Ouvrir package dans Xcode (`open Package.swift`)
- [ ] Build ok (`swift build` ou Cmd+B dans Xcode, 0 erreur)
- [ ] Exécuter la CLI via scheme avec args :
  - [ ] Scheme `mediahub` sélectionné
  - [ ] Arguments configurés dans Edit Scheme (ex: `library create /tmp/test`)
  - [ ] Cmd+R → CLI s'exécute, affiche résultat dans Console
- [ ] Core target isolée :
  - [ ] `MediaHub` (library) ne dépend d'aucun code CLI
  - [ ] `MediaHubCLI` (executable) dépend de MediaHub + ArgumentParser
- [ ] App macOS créée et dépendance SPM locale ok :
  - [ ] Projet MediaHubUI créé (File > New > Project)
  - [ ] Package local MediaHub ajouté (Add Local... dans Add Package Dependency)
  - [ ] `import MediaHub` fonctionne dans ContentView.swift
  - [ ] Build ok (Cmd+B)
- [ ] UI MVP branchée sur Core :
  - [ ] UI appelle `LibraryCreator.createLibrary()` (ou autre use case)
  - [ ] Résultat affiché dans l'UI (succès/erreur)
  - [ ] Cmd+R → App s'exécute, UI fonctionnelle
- [ ] Tests / profiling de base :
  - [ ] `swift test` passe (100+ tests)
  - [ ] Tests UI (optionnel) créés et passent
  - [ ] Profiling avec Instruments (optionnel, pour perf)

---

## 9. Questions (max 3, seulement si bloquantes)

**Aucune question bloquante identifiée.**

Votre architecture est déjà optimale. Les étapes ci-dessus devraient vous permettre de créer l'app macOS sans friction.

**Si vous rencontrez des problèmes spécifiques** :
- Permissions/Sandbox : Vérifier les entitlements et Info.plist keys
- Dépendance MediaHub non résolue : Clean build folder, supprimer DerivedData, réouvrir Xcode
- Previews crash : Clean build, relancer Xcode

**Ressources supplémentaires** :
- [Swift Package Manager](https://swift.org/package-manager/)
- [SwiftUI Tutorials (Apple)](https://developer.apple.com/tutorials/swiftui)
- [App Sandbox (Apple)](https://developer.apple.com/documentation/security/app_sandbox)

---

**Bon développement !** 🚀
