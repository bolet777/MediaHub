# Proposition de Design d'Interface Graphique - MediaHub macOS

**Date**: 2026-01-27  
**Version**: Première itération (brainstorm)  
**Plateforme**: macOS avec SwiftUI

---

## Principes de Design

### Philosophie macOS
- **Simplicité visuelle** : Interface épurée, pas de surcharge
- **Sidebar** : Navigation principale via sidebar (style Photos.app)
- **Barre d'outils moderne** : Actions contextuelles dans une barre d'outils
- **Bibliothèque explicite** : Toujours sélectionner explicitement la bibliothèque (pas de bibliothèque active par défaut)

### Workflow Clarifié
- **Création de bibliothèque** : Unifier "créer" et "adopter" dans un workflow unique avec choix explicite
- **Types de médias** : Définir le type de médias (images/vidéos/les deux) lors de l'attachement d'une source
- **Visualisation** : Pas de miniatures dans la première itération (prévoir pour la suite)

---

## Structure de l'Interface

### Architecture Générale

```
┌─────────────────────────────────────────────────────────────┐
│  MediaHub                                    [⚙️] [❌]      │  ← Barre de titre
├──────────┬──────────────────────────────────────────────────┤
│          │  [Bibliothèques ▼]                               │  ← Barre d'outils
│          │  [+ Nouvelle bibliothèque]                        │
│          │                                                   │
│ SIDEBAR  │                                                   │
│          │  CONTENU PRINCIPAL                               │
│          │  (vues détaillées selon sélection)               │
│          │                                                   │
│          │                                                   │
└──────────┴──────────────────────────────────────────────────┘
```

### Sidebar (Navigation Principale)

La sidebar affiche la liste des bibliothèques MediaHub découvertes :

```
┌─────────────────┐
│  Bibliothèques  │
├─────────────────┤
│ 📚 Librairie     │  ← Bibliothèque sélectionnée
│    Amateur       │
│                 │
│ 📚 Librairie    │
│    Pro          │
│                 │
│ [+ Ajouter...]  │  ← Bouton pour ajouter/créer
└─────────────────┘
```

**Comportement** :
- Double-clic sur une bibliothèque = ouvrir la vue détaillée
- Clic simple = sélectionner (affiche les infos dans le contenu principal)
- Menu contextuel : Ouvrir, Afficher dans Finder, Supprimer (métadonnées uniquement)

---

## Vues Principales

### 1. Vue d'Accueil / Dashboard

**Quand affichée** : Au lancement de l'app, ou quand aucune bibliothèque n'est sélectionnée

**Contenu** :
- **Section "Bibliothèques"**
  - Liste des bibliothèques récentes (si disponibles)
  - Bouton principal : **"+ Nouvelle bibliothèque"**
  - Statistiques globales (nombre total de bibliothèques)

- **Section "Activité récente"**
  - Derniers imports
  - Dernières détections
  - Notifications/alertes (erreurs, collisions résolues)

**Design** : Vue simple, centrée, avec call-to-action principal

---

### 2. Vue de Création/Adoption de Bibliothèque

**Accès** : Bouton "+ Nouvelle bibliothèque" ou menu "Fichier > Nouvelle bibliothèque"

**Workflow unifié** :

```
┌─────────────────────────────────────────────────────┐
│  Nouvelle bibliothèque MediaHub                      │
├─────────────────────────────────────────────────────┤
│                                                       │
│  Comment voulez-vous créer cette bibliothèque ?      │
│                                                       │
│  ○ Créer une nouvelle bibliothèque vide              │
│     Crée une bibliothèque MediaHub à partir de zéro  │
│                                                       │
│  ● Adopter une bibliothèque existante                │
│     Utilise un dossier existant organisé en YYYY/MM  │
│     (Aucun fichier ne sera modifié)                  │
│                                                       │
│  [Chemin: /Volumes/Photos/...] [Parcourir...]       │
│                                                       │
│  [Aperçu] (si adoption)                              │
│  • Structure détectée : YYYY/MM                      │
│  • Fichiers trouvés : 1,234                          │
│  • Métadonnées à créer : .mediahub/library.json      │
│                                                       │
│  [Annuler]  [Créer la bibliothèque]                 │
└─────────────────────────────────────────────────────┘
```

**Étapes** :

1. **Choix du type** : Radio buttons pour "Créer" vs "Adopter"
2. **Sélection du chemin** : NSOpenPanel
   - Mode "Créer" : Sélectionner un dossier (vide ou non, MediaHub créera la structure)
   - Mode "Adopter" : Sélectionner un dossier existant avec médias organisés
3. **Aperçu (si adoption)** :
   - Afficher un résumé du scan baseline (dry-run)
   - Nombre de fichiers trouvés
   - Structure détectée
   - Avertissement : "Aucun fichier média ne sera modifié"
4. **Confirmation** : Bouton "Créer la bibliothèque" avec confirmation explicite

**Clarification dans l'UI** :
- Texte explicatif pour chaque option
- Avertissement clair pour l'adoption : "Aucun fichier ne sera modifié, seules les métadonnées MediaHub seront créées"
- Prévisualisation du scan baseline avant confirmation

---

### 3. Vue de Bibliothèque (Détails)

**Quand affichée** : Quand une bibliothèque est sélectionnée dans la sidebar

**Contenu** :

#### En-tête
- Nom de la bibliothèque (chemin ou nom personnalisé si ajouté)
- Chemin complet
- ID de la bibliothèque
- Version

#### Onglets (ou sections) :

**a) Vue d'ensemble**
- Statistiques :
  - Nombre total de fichiers média
  - Taille totale
  - Répartition par année (graphique ou liste)
  - Répartition par type (images vs vidéos)
- Dernière activité (dernier import, dernière détection)

**b) Sources**
- Liste des sources attachées à cette bibliothèque
- Pour chaque source :
  - Chemin
  - Type de médias analysés (Images, Vidéos, Les deux)
  - Dernière détection
  - Statut (nouvelles détections disponibles, erreur, etc.)
  - Actions : Détecter, Importer, Détacher, Modifier

**c) Historique**
- Liste des imports précédents
- Détails : date, source, nombre d'items, résultats

#### Barre d'outils contextuelle
- Actions selon l'onglet sélectionné :
  - Vue d'ensemble : [Afficher dans Finder]
  - Sources : [+ Attacher une source], [Détecter tout], [Importer tout]
  - Historique : [Filtrer...]

---

### 4. Vue d'Attachement de Source

**Accès** : Bouton "+ Attacher une source" dans la vue Bibliothèque > Sources

**Workflow** :

```
┌─────────────────────────────────────────────────────┐
│  Attacher une source                                 │
├─────────────────────────────────────────────────────┤
│                                                       │
│  Bibliothèque : Librairie Amateur                    │
│                                                       │
│  Chemin de la source :                               │
│  [/Volumes/Photos/Sources/iPhone] [Parcourir...]    │
│                                                       │
│  Types de médias à analyser :                        │
│  ☑ Images (JPEG, PNG, HEIC, RAW, etc.)              │
│  ☑ Vidéos (MOV, MP4, AVI, etc.)                      │
│                                                       │
│  [Annuler]  [Attacher la source]                    │
└─────────────────────────────────────────────────────┘
```

**Éléments** :
- Sélection du chemin (NSOpenPanel)
- Checkboxes pour les types de médias :
  - ☑ Images
  - ☑ Vidéos
  - (Les deux peuvent être sélectionnés simultanément)
- Validation avant attachement
- Affichage des erreurs de validation

**Note** : Cette fonctionnalité nécessite une extension du core pour filtrer par type de média. Pour la première itération, on peut commencer avec "Les deux" uniquement et ajouter le filtrage dans une itération suivante.

---

### 5. Vue de Détection

**Accès** : Bouton "Détecter" sur une source dans la vue Bibliothèque > Sources

**Contenu** :

#### Pendant la détection
- Barre de progression
- Message : "Analyse de la source en cours..."
- Indicateur de fichiers scannés

#### Résultats de la détection
- Résumé :
  - Total scanné : X fichiers
  - Nouveaux : Y fichiers
  - Déjà importés : Z fichiers
- Liste des nouveaux items (si pas trop nombreux) :
  - Chemin du fichier
  - Taille
  - Date de modification
  - Type (image/vidéo)
- Actions :
  - [Importer tout] (si nouveaux items disponibles)
  - [Fermer]

**Note** : Pas de miniatures dans la première itération, mais prévoir la structure pour les ajouter plus tard.

---

### 6. Vue d'Import

**Accès** : Bouton "Importer" sur une source, ou depuis les résultats de détection

**Workflow** :

#### Étape 1 : Prévisualisation (Dry-Run)
```
┌─────────────────────────────────────────────────────┐
│  Importer des médias                                 │
├─────────────────────────────────────────────────────┤
│                                                       │
│  Source : /Volumes/Photos/Sources/iPhone             │
│  Bibliothèque : Librairie Amateur                     │
│                                                       │
│  Résumé :                                            │
│  • 45 nouveaux fichiers à importer                    │
│  • Taille totale : 2.3 GB                             │
│  • Organisation : YYYY/MM                             │
│                                                       │
│  [Mode aperçu] (dry-run activé)                      │
│                                                       │
│  [Annuler]  [Importer tout]                          │
└─────────────────────────────────────────────────────┘
```

#### Étape 2 : Confirmation
- Dialog de confirmation avant import réel
- Afficher le nombre d'items et la taille
- Option "Ne plus demander" (préférence)

#### Étape 3 : Import en cours
- Barre de progression détaillée
- Fichier actuel en cours d'import
- Statistiques : X/Y fichiers importés, Z collisions, W erreurs

#### Étape 4 : Résultats
- Résumé :
  - Importés : X fichiers
  - Collisions : Y fichiers (skip/rename selon politique)
  - Erreurs : Z fichiers
- Liste des collisions (si besoin)
- Actions : [Fermer], [Afficher dans Finder]

**Gestion des collisions** :
- Pour la première itération : politique par défaut (skip)
- Afficher les collisions dans les résultats
- Prévoir une vue dédiée pour gérer les collisions dans une itération future

---

### 7. Vue de Statistiques par Bibliothèque

**Accès** : Onglet "Vue d'ensemble" dans la vue Bibliothèque

**Contenu** :

#### Statistiques globales
- Nombre total de fichiers
- Taille totale
- Dernière activité

#### Répartition par année
```
┌─────────────────────────────────────┐
│  Médias par année                   │
├─────────────────────────────────────┤
│  2024  ████████████  1,234 fichiers │
│  2023  ██████████    987 fichiers   │
│  2022  ████████      654 fichiers   │
│  2021  █████         321 fichiers   │
└─────────────────────────────────────┘
```

#### Répartition par type
- Images : X fichiers
- Vidéos : Y fichiers
- Graphique en secteurs ou barres

**Note** : Ces statistiques nécessitent un scan de la bibliothèque. Pour la première itération, on peut utiliser le baseline index (Slice 7) s'il est disponible, sinon un scan à la demande.

---

## Composants Réutilisables

### 1. BibliothèqueCard
- Affiche les infos d'une bibliothèque (nom, chemin, stats)
- Utilisé dans la sidebar et dans les listes

### 2. SourceCard
- Affiche les infos d'une source (chemin, type de médias, statut)
- Utilisé dans la vue Bibliothèque > Sources

### 3. ProgressIndicator
- Barre de progression avec message
- Utilisé pour détection et import

### 4. ConfirmationDialog
- Dialog de confirmation réutilisable
- Utilisé pour import, suppression, etc.

### 5. ErrorAlert
- Affichage des erreurs de manière claire
- Actions suggérées si applicable

---

## Menus et Actions

### Menu Principal macOS

**MediaHub**
- À propos de MediaHub
- Préférences... (minimal pour première itération)
- Quitter MediaHub

**Fichier**
- Nouvelle bibliothèque...
- Ouvrir une bibliothèque...
- Fermer la fenêtre

**Bibliothèque** (si une bibliothèque est sélectionnée)
- Afficher dans Finder
- Supprimer les métadonnées... (avec confirmation)
- Exporter les statistiques...

**Source** (si une source est sélectionnée)
- Détecter
- Importer tout
- Détacher... (avec confirmation)

**Édition**
- Annuler
- Refaire
- (Standard macOS)

**Fenêtre**
- (Standard macOS)

**Aide**
- Aide MediaHub
- (Standard macOS)

---

## Préférences (Minimal - Première Itération)

**Fenêtre de préférences** :

```
┌─────────────────────────────────────┐
│  Préférences MediaHub               │
├─────────────────────────────────────┤
│                                     │
│  Général                            │
│                                     │
│  Comportement des collisions :     │
│  ○ Ignorer (skip)                   │
│  ○ Renommer                         │
│  ○ Erreur                           │
│                                     │
│  Notifications :                    │
│  ☑ Imports terminés                 │
│  ☑ Erreurs                          │
│                                     │
│  [Fermer]                           │
└─────────────────────────────────────┘
```

**Note** : Garder minimal, ajouter au fur et à mesure selon les besoins.

---

## États et Transitions

### États de l'Application

1. **Aucune bibliothèque** : Afficher la vue d'accueil avec CTA principal
2. **Bibliothèque sélectionnée** : Afficher la vue de bibliothèque
3. **Opération en cours** : Afficher l'indicateur de progression, désactiver les actions destructives
4. **Erreur** : Afficher l'erreur de manière claire avec actions suggérées

### Transitions

- **Création de bibliothèque** : Sidebar → Dialog création → Sidebar (bibliothèque ajoutée)
- **Attachement de source** : Vue Bibliothèque → Dialog attachement → Vue Bibliothèque (source ajoutée)
- **Détection** : Vue Bibliothèque > Sources → Dialog détection → Résultats → Actions
- **Import** : Résultats détection → Dialog confirmation → Progression → Résultats

---

## Questions Techniques à Résoudre

### 1. Filtrage par Type de Médias
**Question** : Le core supporte-t-il actuellement le filtrage par type (images/vidéos) lors de la détection ?

**Réponse** : D'après le code, `MediaFileFormat` distingue images et vidéos, mais la détection actuelle ne filtre pas. Il faudra ajouter un paramètre de filtre dans `SourceScanning` et `DetectionOrchestration`.

**Solution pour première itération** : Commencer avec "Les deux" uniquement, ajouter le filtrage dans une itération suivante.

### 2. Statistiques par Bibliothèque
**Question** : Comment obtenir les statistiques (nombre de fichiers, répartition par année) ?

**Réponse** : Utiliser `LibraryContentQuery` pour scanner la bibliothèque, ou utiliser le baseline index (Slice 7) s'il est disponible.

**Solution pour première itération** : Scan à la demande lors de l'ouverture de la vue d'ensemble, avec indicateur de chargement.

### 3. Découverte des Bibliothèques
**Question** : Comment découvrir toutes les bibliothèques MediaHub sur le système ?

**Réponse** : Utiliser `LibraryDiscoverer.discoverAll()` qui scanne les volumes montés.

**Solution** : Appeler au lancement de l'app et lors du rafraîchissement de la sidebar.

### 4. Persistance de l'État
**Question** : Faut-il sauvegarder l'état de l'application (bibliothèque sélectionnée, fenêtre ouverte) ?

**Réponse** : Pour la première itération, non. L'app démarre toujours sur la vue d'accueil.

---

## Roadmap UI (Itérations Futures)

### Itération 1 (Actuelle)
- ✅ Structure de base avec sidebar
- ✅ Création/adoption de bibliothèque
- ✅ Attachement de sources
- ✅ Détection et import (tout importer)
- ✅ Vue d'ensemble avec statistiques basiques
- ✅ Gestion des collisions (skip par défaut)

### Itération 2
- Miniatures dans les listes de détection/import
- Sélection individuelle d'items pour import
- Vue dédiée pour gérer les collisions
- Préférences avancées

### Itération 3
- Intégration Finder (menu contextuel)
- Drag & drop pour attacher des sources
- Notifications système
- Raccourcis clavier personnalisés

### Itération 4+
- Visualisation des médias (si nécessaire, mais pas prioritaire selon Constitution)
- Métadonnées enrichies
- Recherche avancée
- Export/partage

---

## Notes de Design

### Couleurs et Thème
- Respecter le thème système (clair/sombre)
- Utiliser les couleurs système macOS
- Accent color pour les actions principales

### Typographie
- Utiliser les polices système (SF Pro)
- Hiérarchie claire (titre, sous-titre, corps)

### Espacement
- Respecter les guidelines macOS (espacement cohérent)
- Utiliser les composants SwiftUI standards

### Accessibilité
- Support VoiceOver
- Contraste suffisant
- Tailles de texte ajustables

---

## Conclusion

Cette proposition de design respecte :
- ✅ Les principes de la Constitution MediaHub
- ✅ La philosophie macOS (simplicité, sidebar, barre d'outils moderne)
- ✅ Le workflow clarifié (création/adoption unifiée)
- ✅ Les besoins exprimés (types de médias, statistiques, etc.)
- ✅ La première itération (minimal mais fonctionnel)

**Prochaines étapes** :
1. Valider cette proposition
2. Créer des maquettes plus détaillées si nécessaire
3. Commencer l'implémentation avec SwiftUI
4. Itérer selon les retours
