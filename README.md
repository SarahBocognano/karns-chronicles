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
Aelis, Brenna, Oswin, Mirabelle, Godric, Pépin et le Forgeron.

### L'auberge
Torvald, Théobald Lunebrise, Barnabé et l'inconnu encapuchonné.

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

## Crédits

- Tilesets et décors : **Szadi art** (packs RPG Worlds, dont *Caves* : voir `assets/sprites/tilesets/Caves/LICENSE_szadiart.txt`).
- Police : **Cinzel** (Google Fonts, licence SIL Open Font License).

## À venir

- Système de combat : transition animée, écran de combat vu de face avec un décor.
- Mini quête de Pépin : il vole la bourse de Zylrak et tombe dans une embuscade de monstres.
- Nouvelles cartes : le lac, les ruines, l'intérieur de la grotte.
