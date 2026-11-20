# Karn's Chronicles

Petit projet de démo d'un **RPG 2D en pixel art**, réalisé avec **Godot 4.7**.

Le but est de construire, pas à pas, le début d'un RPG à l'ancienne : un village à explorer, des personnages à qui parler, des quêtes qui s'enchaînent selon ce que le joueur a déjà fait, une première zone dangereuse hors du village, et des combats au tour par tour.

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
3. Appuyer sur **F5** : le jeu s'ouvre sur l'écran titre (Continuer, Nouvelle partie, Charger, Quitter). Pour tester une carte directement, l'ouvrir et appuyer sur **F6**.

Le jeu s'affiche en plein écran, en 1920×1080 (étiré selon la taille de l'écran).

## Commandes

| Touche | Action |
| --- | --- |
| Flèches | Déplacer Zylrak |
| Entrée | Parler, lire la réplique suivante |
| M | Afficher / masquer la mini-carte |
| Échap | Ouvrir le grimoire (Équipe, Équipement, Objets, Précieux, Journal, Système) ; dans un menu : revenir en arrière |
| Clic sur le haut-parleur (en haut à droite) | Couper / remettre la musique |

## Contenu actuel

### Le village
Aelis, Brenna, Oswin, Mirabelle, Godric, Pépin et le Forgeron.

- Des **enseignes** distinguent les bâtiments : une chope pour l'auberge, une enclume pour la forge.
- **Le village du jeu est recentré** (`scenes/maps/VillageV2Map.tscn`, généré par `tools/make_village_v2.gd`) : l'auberge donne sur la place du puits, face à la route qui arrive de la forêt, la forge est dans la rue de l'ouest. Le village d'origine, dessiné à la main (`scenes/maps/VillageMap.tscn`), reste dans le dépôt comme référence. Le générateur corrige aussi deux défauts de la carte d'origine : les marches de la forge ne passent plus sur la tête de Zylrak, et les sapins retrouvent leur pointe (elle était coupée à plat).

### Les coffres
Six coffres sont cachés dans le village, la forêt et les ruines (coffre en bois cerclé de fer pour les objets, coffre précieux doré pour l'équipement). On les ouvre avec Entrée : potions, fioles, et de l'équipement (Carquois tressé, Cotte de mailles, Talisman des Cendres). Un coffre ouvert le reste, même après une sauvegarde.

### L'auberge
Torvald, Théobald Lunebrise, Barnabé et l'inconnu encapuchonné.

### La forêt (au sud du village)
Trois petites cartes, reliées par les chemins (la musique continue de l'une à l'autre) :
- **La lisière** : le chemin qui descend du village, un carrefour et une prairie d'herbes hautes.
- **La cascade** (à l'ouest) : un ruisseau qui tombe de la falaise, un étang et un pont de rondins ; le chemin du lac est encore fermé.
- **Le chariot** (à l'est) : **le chariot du marchand**, renversé sur la route. Une fois la quête d'Oswin acceptée, Zylrak y trouve des indices qui mènent vers les ruines. Un sentier monte de la route jusqu'à **une grotte**, creusée dans la paroi du nord ; on ne peut pas encore l'explorer (il faut une torche). À l'est, la route mène aux ruines (une fois le chariot trouvé).
- Le vent fait doucement balancer les arbres, les buissons et les herbes (shader `vent.gdshader`).
- Des **zones de rencontres aléatoires** partout hors de l'entrée.

### Les menus
- **Écran titre** au lancement : Continuer (la dernière sauvegarde), Nouvelle partie, Charger, Quitter.
- **Nouvelle partie** : une intro à l'ancienne (prologue qui s'écrit lettre par lettre sur les cartes du jeu ; Entrée pour la passer), puis Zylrak arrive au village par la route de la forêt et marche seul jusqu'à l'auberge ; coupure au noir, et Oswin lui tombe dessus.
- **Le grimoire** (Échap, sur les cartes, hors combat et hors dialogue ; le jeu est en pause), aux couleurs du pack *Dark Ages UI* : cadre orné, onglets, parchemins, cases d'inventaire.
  - ← → pour changer d'onglet, Entrée pour entrer dans l'onglet, Échap pour revenir puis fermer.
  - **Équipe** : une fiche par héros (portrait, niveau, barres PV / PM / XP, caractéristiques, Signes ou talents).
  - **Équipement** : arme, armure et accessoire pour Zylrak et Ysolde ; on voit l'effet sur les caractéristiques avant d'équiper. Zylrak trouve l'*Anneau du marchand* sous les caisses du chariot.
  - **Objets** : grille d'inventaire avec icônes, description, et à qui donner potions et fioles.
  - **Précieux** : les fragments gravés des Yrenn.
  - **Journal** : les quêtes en cours et leurs étapes.
  - **Système** : sauvegarder n'importe où dans l'un des **3 emplacements** (lieu, niveau, temps de jeu, date), charger, revenir à l'écran titre.

### Les combats
- Au tour par tour, déclenchés au hasard dans les zones dangereuses.
- **Zylrak** : Attaque, Signes (Feu, Rempart de cendres, Phoenix…), Objets, Fuite.
- **Ysolde**, une fois qu'elle l'a rejoint : Attaque (un tir à l'arc), Talents (Flèche perçante, Pluie de flèches, **Pillage** : elle dérobe une potion ou une fiole de mana à un monstre), Objets, Fuite.
- Potions et fioles se donnent à l'allié de son choix ; un héros à terre se relève à la victoire ; la défaite n'arrive que si toute l'équipe tombe.
- Montée de niveau : Ysolde progresse avec Zylrak.

### Les ruines des Yrenn (à l'est de la forêt)
- **La montée** : une clairière semée de ruines, une paroi rocheuse et son escalier de pierre. Ysolde y attend Zylrak, puis le suit partout.
- **Le parvis du temple** : une façade taillée au pied d'une crête, sa porte scellée à la pierre bleue, et le ciel d'aube au-dessus des sommets.
- **L'énigme de la porte** : en arrivant au parvis, Zylrak suit les traces de sang jusqu'à la porte, scellée par un voile de lumière magique. Quatre encoches attendent des pierres gravées : il faut retrouver les **quatre fragments** qui brillent dans les ruines (deux sur la montée, deux sur le parvis), puis les poser dans le bon ordre. Théobald, à l'auberge, en donne l'indice.

### Le temple des Yrenn (derrière la porte scellée)
Trois salles, de plus en plus profondes (générées par `tools/make_temple.gd`) :
- **Le vestibule** : quatre fresques murales racontent la Bête (on les lit avec Entrée, au pied du mur). Au milieu, un cercle tracé à la cendre : la flamme de l'Ordre des Cendres, renversée, peinte avec le sang du marchand.
- **La galerie** : un long couloir hanté par des goules, des zombies et des squelettes, avec une alcôve de chaque côté (l'Amulette des Yrenn, des potions).
- **La salle du gardien** : le grand cercle rituel, les sceaux au sol, des statues de mages yrenn, des torches et des braseros. Au fond, devant l'autel, se dresse le gardien, et le corps du marchand gît à côté.

**Les gardiens et les fragments d'âme.** Les Yrenn ont brisé l'âme de la Bête en quatre éclats, un par temple, et lié leurs propres âmes aux sceaux pour les garder. Sous la lune noire, l'éclat a dévoré le Yrenn qui le gardait et pris son armure ; le culte (des membres renégats de l'Ordre des Cendres) a brisé le sceau avec le sang du marchand. Zylrak doit donc vaincre le gardien corrompu (on ne peut pas fuir ce combat), puis enfermer dans la cendre la braise noire qui s'en échappe : c'était le rôle des Ashwardens, héritiers des Yrenn. Il obtient le **fragment d'âme** ; sur l'autel, le **parchemin des Yrenn** explique qu'il faut réunir les quatre et les rendre ensemble à la flamme pour resceller la Bête, et indique le prochain temple (le Loup, sous le lac). Zylrak examine le corps du marchand, puis rentre l'annoncer à Oswin, qui le récompense : la quête du marchand s'arrête là.

## Organisation du projet

```
assets/
  fonts/        police Cinzel
  portrait/     portraits des PNJ (planches d'expressions + AtlasTexture par expression)
  sprites/      personnages et tilesets (Szadi art)
  ui/           boîte de dialogue
resources/
  dialogues/    une conversation par fichier .tres, rangées par PNJ
  shaders/      eau animée, vent dans la végétation, ambiance de la forêt
  tilesets/     tilesets de la forêt
scenes/
  characters/   Player.tscn (Zylrak)
  Dialog/       boîte de dialogue et ressources de dialogue
  maps/         cartes (village, auberge, étage, forge, forêt, ruines) et leurs scripts
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
- Coffres : générés avec Copilot dans le style de Szadi art, puis découpés.
- Sang au sol : *Horror Fantasy Assets* par **Stealthix** — CC0 (https://opengameart.org/content/horror-fantasy-assets).
- Fonds de combat : générés avec Copilot, puis pixelisés.
- Temple des Yrenn : fresques murales, sceaux au sol, grand cercle rituel, pierres gravées des fragments, statues de mages, ossements, racines et mousse, fond de combat de la salle, générés avec Copilot ; animations des torches et braseros, cristaux, jarres : Szadi art.
- Enseignes de l'auberge et de la forge : générées avec Copilot, puis réduites et pixelisées.
- Interface (combats et menus) :
  - cadres et contour des barres : *Tiny RPG – Mana Soul GUI* par **Gabriel « tiopalada » Lima** — CC0 (https://tiopalada.itch.io/tiny-rpg-mana-soul-gui) ;
  - remplissages des barres : Pixel UI Fantasy Free by heyheythere - https://heyheythere.itch.io/pixel-ui-fantasy-free - CC BY 4.0 ;
  - grimoire (cadre orné, parchemins, onglets, cases, barres) : *Dark Ages UI* par **Hypnobius** — usage commercial autorisé (https://hypnobius.itch.io/dark-ages-ui) ;
  - main du menu : *Hand cursor* par **andreyin** — CC0 (https://opengameart.org/node/89568).

## À venir

- Mini quête de Pépin : il vole la bourse de Zylrak et tombe dans une embuscade de monstres.
- Nouvelles cartes : le lac et le temple du Loup, l'intérieur de la grotte.
