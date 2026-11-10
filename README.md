# Karn's Chronicles

RPG 2D en pixel art, réalisé avec **Godot 4.7**. On y suit **Zylrak**, un jeune aventurier qui part du village à la recherche d'Aldric, disparu dans la forêt, et enquête sur les attaques de monstres autour des ruines.

## Lancer le jeu

1. Installer [Godot 4.7](https://godotengine.org/download) (version standard, pas .NET).
2. Ouvrir Godot, cliquer sur **Importer** et choisir le fichier `project.godot` de ce dépôt.
3. Ouvrir `scenes/maps/VillageMap.tscn` et appuyer sur **F6** (lancer la scène ouverte). La scène principale `Main.tscn` ne contient pour l'instant que Zylrak.

Le jeu s'affiche en plein écran, en 1920×1080 (étiré selon la taille de l'écran).

## Commandes

| Touche | Action |
| --- | --- |
| Flèches | Déplacer Zylrak |
| Entrée | Parler, lire la réplique suivante |

## Contenu actuel

### Le village
- **Aelis** : remballe Zylrak quand il tente sa chance.
- **Brenna** : lance la quête pour retrouver son frère **Aldric**.
- **Oswin** : donne la quête principale (enquêter sur les attaques) à l'auberge.
- **Mirabelle** : la fleuriste, qui arrose ses fleurs sur la place.
- **Godric** : le vieux bûcheron, oncle d'Aldric et de Brenna.
- **Pépin** : le gamin espiègle qui se moque de Zylrak.
- **Le Forgeron**, dans sa forge.

### L'auberge
- **Torvald** : parle des cris entendus près des ruines.
- **Théobald Lunebrise** : le magicien, qui connaît les Yrenn et leurs symboles.
- **Barnabé** : défie Zylrak au concours de chopes.
- **L'inconnu encapuchonné**, au comportement cryptique.

### La forêt (au sud du village)
- Deux niveaux reliés par un col entre deux falaises.
- Un ruisseau avec une cascade, un étang et un pont de rondins.
- Une prairie d'herbes hautes et un sous-bois.
- **Le chariot du marchand**, renversé sur la route de l'est : une fois la quête d'Oswin acceptée, Zylrak y trouve des indices qui mènent vers les ruines.
- **Une grotte** au sud-est, qu'on ne peut pas encore explorer (il faut une torche).
- Des **zones de rencontres aléatoires** partout hors de l'entrée. Le système de combat n'est pas encore branché.

## Organisation du projet

```
assets/
  fonts/        police Cinzel
  portrait/     portraits des PNJ (planches d'expressions + AtlasTexture par expression)
  sprites/      personnages et tilesets (Szadi art)
  ui/           boîte de dialogue
resources/
  dialogues/    une conversation par fichier .tres, rangées par PNJ
  shaders/      eau animée et ambiance de la forêt
  tilesets/     tilesets de la forêt
scenes/
  characters/   Player.tscn (Zylrak)
  Dialog/       boîte de dialogue et ressources de dialogue
  maps/         cartes (village, auberge, étage, forge, forêt) et leurs scripts
scripts/
  player_data.gd       autoload : PV, inventaire, flags de quête
  scene_transition.gd  autoload : changement de carte avec fondu au noir
```

## Comment ça marche

### Dialogues et quêtes
- Chaque PNJ a un nœud avec le script `scenes/maps/npc_dialogue.gd` et une liste de **conversations** (`DialogueConversation`, dans `resources/dialogues/<pnj>/`).
- Le PNJ joue la **première conversation disponible** de sa liste, selon ses conditions :
  - `required_flags` : flags qui doivent être vrais ;
  - `forbidden_flags` : flags qui doivent être faux.
- À la fin d'une conversation :
  - `flags_on_finish` passe des flags à vrai ;
  - `show_quest_marker` affiche un « ! » au-dessus du PNJ tant que la conversation est disponible ;
  - `auto_start` fait venir le PNJ vers Zylrak dès l'arrivée dans la scène.
- Chaque réplique (`DialogueLine`) a un nom, un portrait et un texte.
- Les flags de quête sont listés dans `scripts/player_data.gd` (`quest_flags`).

### Cartes
- **Passer d'une carte à l'autre** : une `Area2D` appelle `SceneTransition.change_scene(scène, point_d_arrivée)`, et Zylrak réapparaît sur le `Marker2D` du même nom.
- **`map_camera_zoom.gd`**, sur la racine de chaque carte, fixe le zoom et bloque la caméra aux bords du sol.
  - Avec `fill_screen`, la pièce remplit tout l'écran quelle que soit la taille de la fenêtre.
- **`map_message_zone.gd`** fait parler Zylrak quand il entre dans une zone, par exemple un chemin pas encore accessible.
- **`encounter_zone.gd`** marque les zones de rencontres aléatoires.

### Forêt
- La carte `ForestMap.tscn` est générée par un script (relief, eau, arbres, décor). Des retouches à la main dans l'éditeur seraient perdues si on la régénère.
- L'eau est dessinée avec un shader (`resources/shaders/water.gdshader`) sur des `Polygon2D`.
- La brume et les rayons de lumière viennent de `forest_ambience.gdshader`, appliqué sur un `ColorRect`.

## Crédits

- Tilesets et décors : **Szadi art** (packs RPG Worlds, dont *Caves* : voir `assets/sprites/tilesets/Caves/LICENSE_szadiart.txt`).
- Police : **Cinzel** (Google Fonts, licence SIL Open Font License).

## À venir

- Système de combat : transition animée, écran de combat vu de face avec un décor.
- Mini quête de Pépin : il vole la bourse de Zylrak et tombe dans une embuscade de monstres.
- Nouvelles cartes : le lac, les ruines, l'intérieur de la grotte.
