# Karn's Chronicles

Petit projet de démo d'un **RPG 2D en pixel art**, réalisé avec **Godot 4.7**.

Le but est de construire, pas à pas, le début d'un RPG à l'ancienne : un village à explorer, des personnages à qui parler, des quêtes qui s'enchaînent selon ce que le joueur a déjà fait, et une première zone dangereuse hors du village. La suite prévue est un système de combat au tour par tour.

## L'histoire

**Zylrak** est un Ashwarden, un membre de l'Ordre des Cendres. Il est un peu trop sûr de lui et répète son nom à qui veut l'entendre. En arrivant dans un petit village, il le découvre aux abois :
- depuis des semaines, des **goules** rôdent autour du village et les routes sont coupées ;
- le **marchand** qui devait apporter vivres et remèdes n'est jamais arrivé.

À l'auberge, Oswin lui confie l'affaire. Les habitués parlent de cris entendus près des **ruines des Yrenn**, à l'est, un peuple disparu dont personne n'a jamais entièrement déchiffré l'écriture.

Au village, Brenna lui demande aussi de retrouver son frère **Aldric**. Il est parti couper du bois près du lac, dans la forêt au sud, et n'est jamais revenu.

Dans la forêt, Zylrak trouve le chariot du marchand renversé, couvert de marques de griffes. Les traces partent vers les ruines.

Au pied des ruines, une archère, **Ysolde**, le prend pour l'agresseur du marchand et le met en joue. Le quiproquo dissipé, ils font équipe : elle traque les goules depuis des jours. Les traces de sang mènent jusqu'à un temple taillé dans la montagne, dont la porte est scellée...

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
| M | Afficher / masquer la mini-carte |

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
- Des **zones de rencontres aléatoires** partout hors de l'entrée.
- À l'est, la route mène aux ruines (une fois le chariot trouvé).

### Les ruines des Yrenn (à l'est de la forêt)
- **La montée** : une clairière semée de ruines, une paroi rocheuse et son escalier de pierre. Ysolde y attend Zylrak, puis le suit partout.
- **Le parvis du temple** : une façade taillée au pied d'une crête, sa porte scellée à la pierre bleue, et le ciel d'aube au-dessus des sommets.

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
  - ruines : *RPG Worlds Decorative Props* (https://szadiart.itch.io/rpg-worlds-decorative-props) ;
  - temple et escaliers : *RPG Buildings and Interriors – CASTLE* (https://szadiart.itch.io/rpg-buildings).
- Ciel et sommets au-dessus du temple : peints pour le projet (`tools/paint_backdrop.gd`).
- Police : **Cinzel** (Google Fonts, licence SIL Open Font License).
- Monstres morts-vivants : **Fat Cat Games**, pack *10 FREE Undead fantasy JRPG pixelart characters* (https://fatcatgamesstudio.itch.io/10-jrpg-pixelart-battlers).
- Zombie : *[LPC] Zombie* par **Benjamin K. Smith (BenCreating)**, commandé par castelonia, d'après la base LPC de **Stephen Challener (Redshrike)** et les animations de **Johannes Sjölund (wulax)** — CC-BY-SA 3.0 (https://opengameart.org/content/lpc-zombie).
- Musique :
  - village (*The Apothecary*), auberge (*The Tavern Keeper*), forge (*The Blacksmith*) : *Exploration Fantasy Free Pack* par **EugeneDesMusic** — licence GameDev Market (https://www.gamedevmarket.net/asset/exploration-fantasy-free-pack) ;
  - forêt (*Place_Fantasy_Desert_Loop*) : *Music For Your RPG* par **The Sound Guild** — licence GameDev Market (https://www.gamedevmarket.net/asset/music-for-your-rpg) ;
  - ruines (*Sunrise Over the Ruins*) : *Emotional And Cinematic Music Pack for RPGs* par **lullemusic** — licence GameDev Market (https://www.gamedevmarket.net/asset/emotional-and-cinematic-music-pack-for-rpgs) ;
  - combats : *JRPG/RPG Combat Exploration Theme* (version en boucle) par **lardven** — licence GameDev Market (https://www.gamedevmarket.net/asset/jrpgrpg-combat-exploration-theme).
- Sang au sol : *Horror Fantasy Assets* par **Stealthix** — CC0 (https://opengameart.org/content/horror-fantasy-assets).
- Fonds de combat : générés avec Copilot, puis pixelisés.
- Interface de combat :
  - cadres et contour des barres : *Tiny RPG – Mana Soul GUI* par **Gabriel « tiopalada » Lima** — CC0 (https://tiopalada.itch.io/tiny-rpg-mana-soul-gui) ;
  - remplissages des barres : Pixel UI Fantasy Free by heyheythere - https://heyheythere.itch.io/pixel-ui-fantasy-free - CC BY 4.0 ;
  - main du menu : *Hand cursor* par **andreyin** — CC0 (https://opengameart.org/node/89568).

## À venir

- Ysolde au combat, avec son arc.
- L'énigme de la porte scellée du temple (quatre fragments à retrouver et à remettre dans l'ordre).
- Mini quête de Pépin : il vole la bourse de Zylrak et tombe dans une embuscade de monstres.
- Nouvelles cartes : le lac, l'intérieur du temple, l'intérieur de la grotte.
