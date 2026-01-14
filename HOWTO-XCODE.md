# HOWTO-XCODE

Guide de setup et développement MediaHub dans Xcode pour l'équipe de développement.

---

## 0. Architecture finale et découpage

### Architecture haut-niveau

```
┌─────────────────────────────────────────────────────────────┐
│                    MediaHub Repository                       │
│                                                               │
│  ┌──────────────────┐         ┌──────────────────┐        │
│  │  Package SPM      │         │  App Xcode       │        │
│  │  (Core + CLI)     │         │  (SwiftUI)       │        │
│  └──────────────────┘         └──────────────────┘        │
│           │                              │                   │
│           │ import                       │ import            │
│           │                              │                   │
│           └──────────┬───────────────────┘                   │
│                      │                                        │
│              ┌───────▼────────┐                              │
│              │  MediaHub      │                              │
│              │  (Library)     │                              │
│              │  Core Logic    │                              │
│              └────────────────┘                              │
└─────────────────────────────────────────────────────────────┘
```

### Découpage des responsabilités

**1. Package Swift (SPM) - `/Volumes/Photos/_DevTools/MediaHub/`**
- **MediaHub** (library) : Core logique métier UI-agnostic
- **MediaHubCLI** (executable) : CLI tool (`mediahub` command)
- **MediaHubTests** : Tests unitaires et d'intégration
- **Développement** : Cursor (édition) + Terminal (`swift build`, `swift test`)
- **Xcode** : Optionnel pour édition, mais build peut échouer (bug Xcode 26.2)

**2. App SwiftUI - `/Volumes/Photos/_DevTools/MediaHub/MediaHubUI/`**
- **MediaHubUI** (macOS app) : Interface utilisateur SwiftUI
- **Dépendance** : Importe le package MediaHub comme dépendance locale
- **Développement** : Xcode uniquement (build, Previews, Debugger fonctionnent normalement)

### Structure du repository

```
MediaHub/
├── Package.swift                    # Package SPM (Core + CLI)
├── Sources/
│   ├── MediaHub/                    # Core library (logique métier)
│   └── MediaHubCLI/                # CLI executable
├── Tests/
│   └── MediaHubTests/              # Tests unitaires
├── MediaHubUI/                     # App SwiftUI (nouveau)
│   ├── MediaHubUI.xcodeproj        # Projet Xcode
│   └── MediaHubUI/                 # Code SwiftUI
├── docs/                           # Documentation
└── specs/                          # Spec-Kit (architecture)
```

### Règles de dépendances

```
MediaHubUI  →  MediaHub  ←  MediaHubCLI  ←  ArgumentParser
                   ↑
            MediaHubTests
```

- **MediaHub** : Ne dépend de rien d'externe (Foundation uniquement)
- **MediaHubCLI** : Dépend de MediaHub + ArgumentParser
- **MediaHubUI** : Dépend de MediaHub uniquement (import MediaHub, pas MediaHubCLI)
- **Core ne dépend de rien de UI/CLI** : Respect total ✅

### Workflow de développement recommandé

| Composant | Édition | Build/Test | Debug |
|-----------|---------|------------|-------|
| **Package MediaHub** | Cursor | Terminal (`swift build`, `swift test`) | Terminal (LLDB) ou Xcode (breakpoints) |
| **App MediaHubUI** | Xcode | Xcode (Cmd+B) | Xcode (Cmd+R, breakpoints) |

**Note importante** : Même si le build du package MediaHub échoue dans Xcode (bug Xcode 26.2 avec fichiers de dépendances), l'app SwiftUI fonctionnera parfaitement. L'app est un projet Xcode standard qui importe MediaHub comme dépendance, ce qui est mieux géré par Xcode que les packages SPM directement.

---

## 1. Plan de match : Setup initial

### Étape 1 : Vérifier les prérequis

**Prérequis système** :
- **Xcode** : Xcode 15.0+ (recommandé) ou Xcode 26.2 (beta, peut avoir des bugs)
- **macOS** : macOS 13 Ventura ou plus récent
- **Command Line Tools** : Installer avec `xcode-select --install` si pas déjà fait

**Vérification** :
```bash
xcodebuild -version    # Doit afficher Xcode 15.0+ ou 26.2
swift --version        # Doit afficher Swift 5.9+
```

### Étape 2 : Cloner et valider le package

```bash
# Cloner le repository (ou naviguer vers le répertoire existant)
cd /Volumes/Photos/_DevTools/MediaHub

# Valider que le package compile
swift build

# Exécuter les tests
swift test

# Tester la CLI
swift run mediahub --help
```

**Résultats attendus** :
- ✅ `swift build` → `Build complete!`
- ✅ `swift test` → `Test Suite 'All tests' passed` (100+ tests)
- ✅ `swift run mediahub --help` → Affiche l'aide de la CLI

### Étape 3 : Setup Xcode pour le Package (optionnel)

**⚠️ Limitation connue** : Le build du package dans Xcode peut échouer avec l'erreur "unable to open dependencies file" (bug Xcode 26.2). Le package compile parfaitement depuis le terminal.

**Si vous voulez quand même utiliser Xcode pour le package** :

1. Ouvrir le package dans Xcode :
   ```bash
   cd /Volumes/Photos/_DevTools/MediaHub
   open Package.swift
   ```

2. Attendre la fin de l'indexation (barre de progression en haut)

3. Si erreur de build : Utiliser le terminal pour build/test (voir workflow recommandé ci-dessus)

**Note** : Même si le build échoue dans Xcode, vous pouvez utiliser Xcode pour :
- Éditer le code
- Naviguer dans le code
- Utiliser les breakpoints (si vous lancez depuis le terminal)

### Étape 4 : Créer l'app SwiftUI dans Xcode

**Cette étape est obligatoire pour développer l'UI.**

Voir section **4. Créer l'app SwiftUI** pour les instructions détaillées.

---

## 2. Développement du Package (Core + CLI)

### 2.1 Workflow recommandé

**Édition** : Cursor (ou votre éditeur préféré)
**Build/Test** : Terminal
**Debug** : Terminal (LLDB) ou Xcode (breakpoints)

### 2.2 Commandes terminal essentielles

```bash
cd /Volumes/Photos/_DevTools/MediaHub

# Build
swift build

# Tests
swift test

# Test spécifique
swift test --filter LibraryCreationTests

# Exécuter la CLI
swift run mediahub library create /tmp/test-library
swift run mediahub status --library /tmp/test-library

# Debug avec LLDB
swift build
lldb .build/debug/mediahub
(lldb) run library create /tmp/test
```

### 2.3 Structure du Package

**Package.swift** :
- **Swift tools version** : 5.9
- **Platforms** : macOS 13+
- **Products** :
  - `MediaHub` (library) — Core logique métier
  - `mediahub` (executable) — CLI tool
- **Targets** :
  - `MediaHub` (library) — Logique métier UI-agnostic
  - `MediaHubCLI` (executable) — CLI wrapper
  - `MediaHubTests` — Tests

**Sources/MediaHub/** : Core library (Library, Source, Import, Detection, Tracking)
**Sources/MediaHubCLI/** : CLI commands, formatters, progress indicators

### 2.4 Utiliser Xcode pour le Package (optionnel)

**Ouvrir le package** :
```bash
cd /Volumes/Photos/_DevTools/MediaHub
open Package.swift
```

**Pièges fréquents** :
- **Indexation lente** : Attendre la fin (barre de progression en haut)
- **Erreur "unable to open dependencies file"** : Bug Xcode 26.2, utiliser le terminal pour build/test
- **Caches corrompus** : Nettoyer avec `rm -rf ~/Library/Developer/Xcode/DerivedData/MediaHub-*`

**Si le build échoue dans Xcode** :
- Utiliser le terminal pour build/test (`swift build`, `swift test`)
- Xcode peut toujours être utilisé pour l'édition et la navigation
- Les breakpoints fonctionnent si vous lancez depuis le terminal

---

## 3. Développement de l'App SwiftUI

### 3.1 Workflow recommandé

**Tout dans Xcode** :
- Édition : Xcode
- Build : Xcode (Cmd+B)
- Test : Xcode (Cmd+R)
- Debug : Xcode (breakpoints, LLDB)
- Previews : Xcode (Canvas)

### 3.2 Créer l'app SwiftUI

**Étape 1 : Créer le projet Xcode**

1. `File > New > Project...`
2. Choisir `macOS` (onglet en haut) → `App` (template)
3. Configuration :
   - **Product Name** : `MediaHubUI`
   - **Organization Identifier** : `com.mediahub` (ou votre domaine)
   - **Interface** : SwiftUI
   - **Language** : Swift
   - **Storage** : None
4. **Emplacement** : `/Volumes/Photos/_DevTools/MediaHub/MediaHubUI/`
5. **Add to** : Laisser vide (pas de workspace)
6. **Create Git repository** : Décocher (repo déjà existant)
7. Cliquer `Create`

**Étape 2 : Ajouter le package MediaHub comme dépendance**

1. Sélectionner le projet `MediaHubUI` dans le navigateur (à gauche)
2. Sélectionner le target `MediaHubUI` (sous `TARGETS`)
3. Onglet `General` → Section `Frameworks, Libraries, and Embedded Content`
4. Cliquer `+` → `Add Other...` → `Add Package Dependency...`
5. Cliquer `Add Local...` (en bas)
6. Naviguer vers `/Volumes/Photos/_DevTools/MediaHub/` (répertoire contenant Package.swift)
7. Cliquer `Add Package`
8. Dans la liste des produits, **cocher `MediaHub`** (library, pas `mediahub` executable)
9. Cliquer `Add Package`

**Étape 3 : Importer et utiliser MediaHub**

Ouvrir `ContentView.swift` et ajouter :

```swift
import SwiftUI
import MediaHub

struct ContentView: View {
    @State private var libraryPath: String = ""
    @State private var statusMessage: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("MediaHub UI")
                .font(.largeTitle)

            TextField("Library Path", text: $libraryPath)
                .textFieldStyle(.roundedBorder)

            Button("Create Library") {
                createLibrary(at: libraryPath)
            }

            Text(statusMessage)
        }
        .padding()
    }

    func createLibrary(at path: String) {
        let creator = LibraryCreator()
        creator.createLibrary(at: path) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let metadata):
                    statusMessage = "Library created: \(metadata.libraryId)"
                case .failure(let error):
                    statusMessage = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
}
```

**Étape 4 : Build et Run**

1. `Product > Build` (Cmd+B) — doit compiler sans erreur
2. `Product > Run` (Cmd+R) — l'app s'exécute

### 3.3 Structure de l'app

```
MediaHubUI/
├── MediaHubUI.xcodeproj          # Projet Xcode
├── MediaHubUI/
│   ├── MediaHubUIApp.swift      # Point d'entrée de l'app
│   ├── ContentView.swift        # Vue principale
│   └── Assets.xcassets          # Assets (icônes, images)
└── ...
```

### 3.4 Développement dans Xcode

**Previews SwiftUI** :
- Activer le Canvas : `Editor > Canvas` (Cmd+Option+Return)
- Les previews se mettent à jour automatiquement lors de l'édition

**Debug** :
- Breakpoints : Cliquer dans la gouttière (à gauche du numéro de ligne)
- Console LLDB : `View > Debug Area > Show Debug Area` (Cmd+Shift+Y)
- Commandes LLDB utiles :
  - `po <variable>` : Afficher une variable
  - `p <expression>` : Évaluer une expression
  - `bt` : Backtrace (call stack)

**Build configurations** :
- Debug (par défaut) : Optimisations désactivées, symboles inclus
- Release : `Product > Scheme > Edit Scheme...` → `Run` → `Info` → `Build Configuration` → `Release`

---

## 4. Permissions et Entitlements

### 4.1 Signing

1. Sélectionner le projet `MediaHubUI` → Target `MediaHubUI`
2. Onglet `Signing & Capabilities`
3. **Automatically manage signing** : Cocher
4. **Team** : Sélectionner votre Apple Developer Team (ou "Personal Team")

### 4.2 Entitlements

Dans `Signing & Capabilities`, ajouter :

- **App Sandbox** : Activé par défaut
- **File Access** (dans App Sandbox) :
  - **User Selected File** : Read/Write (pour NSOpenPanel)
  - **Downloads Folder** : Read/Write (si besoin)
  - **Pictures Folder** : Read/Write (si besoin)

### 4.3 Info.plist keys

Dans `Info` (target settings), ajouter si nécessaire :

- `NSRemovableVolumesUsageDescription` : "MediaHub needs access to external drives to manage media libraries."
- `NSNetworkVolumesUsageDescription` : "MediaHub needs access to network drives to manage media libraries."

---

## 5. Troubleshooting

### 5.1 Package : Erreur "unable to open dependencies file"

**Symptôme** : Build échoue dans Xcode avec erreur sur fichiers `.d`

**Cause** : Bug Xcode 26.2 (beta) avec gestion des fichiers de dépendances

**Solution** :
1. Utiliser le terminal pour build/test : `swift build`, `swift test`
2. Xcode peut toujours être utilisé pour l'édition
3. Si nécessaire, utiliser Xcode 15.x (stable) au lieu de 26.2 (beta)

### 5.2 App : "No such module 'MediaHub'"

**Symptôme** : Erreur d'import dans l'app SwiftUI

**Solution** :
1. Vérifier que le package MediaHub est bien ajouté comme dépendance (section 3.2)
2. `Product > Clean Build Folder` (Cmd+Shift+K)
3. Rebuild : `Product > Build` (Cmd+B)

### 5.3 App : Previews ne fonctionnent pas

**Symptôme** : Canvas ne s'affiche pas ou crash

**Solution** :
1. `Product > Clean Build Folder` (Cmd+Shift+K)
2. Fermer et réouvrir le Canvas : `Editor > Canvas`
3. Si nécessaire, relancer Xcode

### 5.4 Caches corrompus

**Nettoyer les caches** :

```bash
# DerivedData Xcode
rm -rf ~/Library/Developer/Xcode/DerivedData/MediaHub-*

# Build cache SPM
cd /Volumes/Photos/_DevTools/MediaHub
rm -rf .build

# Package caches
swift package clean
```

Puis réouvrir Xcode et rebuild.

---

## 6. Checklist de setup pour l'équipe

### Setup initial

- [ ] Xcode 15.0+ installé
- [ ] Repository cloné : `/Volumes/Photos/_DevTools/MediaHub`
- [ ] Package valide : `swift build` et `swift test` passent
- [ ] CLI fonctionne : `swift run mediahub --help` affiche l'aide

### Setup Xcode pour le Package (optionnel)

- [ ] Package ouvert dans Xcode : `open Package.swift`
- [ ] Indexation terminée (barre de progression)
- [ ] Si erreur de build : Utiliser le terminal pour build/test

### Setup App SwiftUI (obligatoire pour UI)

- [ ] Projet MediaHubUI créé dans `/Volumes/Photos/_DevTools/MediaHub/MediaHubUI/`
- [ ] Package MediaHub ajouté comme dépendance locale
- [ ] `import MediaHub` fonctionne dans ContentView.swift
- [ ] Build ok : `Product > Build` (Cmd+B) sans erreur
- [ ] Run ok : `Product > Run` (Cmd+R) lance l'app
- [ ] Previews fonctionnent : Canvas affiche la preview

### Développement

- [ ] Workflow Package : Cursor + Terminal (`swift build`, `swift test`)
- [ ] Workflow App : Xcode (build, run, debug, previews)
- [ ] Permissions configurées : Signing & Capabilities
- [ ] Tests passent : `swift test` (Package) et tests UI (App)

---

## 7. Ressources

- [Swift Package Manager](https://swift.org/package-manager/)
- [SwiftUI Tutorials (Apple)](https://developer.apple.com/tutorials/swiftui)
- [App Sandbox (Apple)](https://developer.apple.com/documentation/security/app_sandbox)
- [Xcode User Guide](https://developer.apple.com/documentation/xcode)

---

**Bon développement !** 🚀
