# Karn's Chronicles

Petit projet de démo d'un **RPG 2D en pixel art**, réalisé avec **Godot 4.7**.

Le but est de construire, pas à pas, le début d'un RPG à l'ancienne : un village à explorer, des personnages à qui parler, des quêtes qui s'enchaînent selon ce que le joueur a déjà fait, une première zone dangereuse hors du village, et des combats au tour par tour.

## L'histoire

**Zylrak** est un Ashwarden, un membre de l'Ordre des Cendres. Il est un peu trop sûr de lui et répète son nom à qui veut l'entendre. En arrivant au village d'Eclatvin, il le découvre aux abois :
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

### Version web (navigateur, ordinateur et téléphone)

1. Installer les modèles d'export de Godot 4.7.2 (dans l'éditeur : **Éditeur > Gérer les modèles d'export**). Seuls les fichiers `web_*` servent ici.
2. Exporter avec le preset **Web** (`export_presets.cfg`) depuis l'éditeur, ou en ligne de commande :
   ```bash
   godot --headless --path . --export-release "Web" build/web/index.html
   ```
3. Servir le dossier `build/web/` (ouvrir `index.html` directement depuis le disque ne marche pas) :
   ```bash
   python3 -m http.server 8060 --directory build/web
   ```
   puis ouvrir http://localhost:8060.

### Le site en ligne

Le jeu est jouable sur **https://sarahbocognano.github.io/karns-chronicles/**, avec sa page de présentation (le monde, les personnages, des captures, les commandes au clavier et au doigt).

- La page vient du dossier `site/` (`index.html`, `style.css`, `img/`) ; un fichier `.gdignore` empêche Godot de l'importer.
- À chaque push sur `main`, le workflow `.github/workflows/site-web.yml` exporte le jeu dans `jeu/`, y ajoute la page, et publie le tout sur GitHub Pages (quelques minutes). On peut aussi le relancer à la main depuis l'onglet **Actions**.
- Pour voir le site en local avant de pousser :
  ```bash
  rm -rf build/site && mkdir -p build/site && cp -R site/. build/site/ && cp -R build/web/. build/site/jeu/
  ```
  ```bash
  python3 -m http.server 8061 --directory build/site
  ```

Le build est en un seul fil d'exécution : il n'a besoin d'aucun en-tête serveur particulier et se dépose tel quel sur itch.io ou un hébergement statique. Il pèse environ 80 Mo à télécharger (compressé). Sur le web, l'écran garde le format 16:9 (bandes noires sur les côtés si la fenêtre est plus large), le rendu passe automatiquement en *Compatibility* (WebGL 2), et l'écran titre n'a pas d'option Quitter. Le son est mixé par le jeu comme sur ordinateur (`audio/general/default_playback_type.web` en *Stream*) : le mode *Sample*, par défaut sur le web, ne suit pas les fondus de volume de la musique et des ambiances, et le jeu restait muet. Les planches de portraits `assets/portrait/1.png`, `2.png` et `3.png`, inutilisées, ne sont pas exportées. Navigateurs conseillés : Chrome ou Firefox ; Safari a des soucis connus avec WebGL 2.

## Commandes

| Touche | Action |
| --- | --- |
| Flèches | Déplacer Zylrak |
| Entrée | Parler, lire la réplique suivante |
| M | Afficher / masquer la mini-carte |
| Échap | Ouvrir le grimoire (Équipe, Équipement, Objets, Précieux, Journal, Système) ; dans un menu : revenir en arrière |
| Clic sur le haut-parleur (en haut à droite) | Couper / remettre la musique |

**Sur téléphone ou tablette** (version web), des contrôles tactiles apparaissent (`scripts/tactile.gd`) : une croix à gauche pour se déplacer et naviguer dans les menus, **A** (Entrée), **B** (Échap) et **Carte** (M) à droite. Chaque bouton envoie au jeu la même touche que le clavier. Les aides affichées à l'écran disent alors A et B au lieu d'Entrée et Échap. Les contrôles se cachent dès qu'on joue au clavier et reviennent au premier contact du doigt. Le jeu se joue en paysage : en portrait, un message demande de tourner l'appareil.

## Contenu actuel

### Le village
Aelis, Brenna, Oswin, Mirabelle, Godric, Pépin, le Forgeron, et la mère Margot (dans sa ferme-fournil, au bout du chemin du nord-est).

- Des **enseignes** distinguent les bâtiments : une chope pour l'auberge, une enclume pour la forge.
- **Le poteau indicateur**, à l'entrée du village par la route de la forêt, se lit avec Entrée.
- **Le village du jeu est recentré** (`scenes/maps/VillageV2Map.tscn`, généré par `tools/make_village_v2.gd`) : l'auberge donne sur la place du puits, face à la route qui arrive de la forêt, la forge est dans la rue de l'ouest. Le village d'origine, dessiné à la main (`scenes/maps/VillageMap.tscn`), reste dans le dépôt comme référence. Le générateur corrige aussi deux défauts de la carte d'origine : les marches de la forge ne passent plus sur la tête de Zylrak, et les sapins retrouvent leur pointe (elle était coupée à plat).

### Les coffres
Six coffres sont cachés dans le village, la forêt et les ruines (coffre en bois cerclé de fer pour les objets, coffre précieux doré pour l'équipement). On les ouvre avec Entrée : potions, fioles, et de l'équipement (Carquois tressé, Cotte de mailles, Talisman des Cendres). Un coffre ouvert le reste, même après une sauvegarde.

### Les contrats et la boutique
- **Le panneau des contrats**, à droite de l'auberge : une fois la quête d'Oswin acceptée, il affiche deux contrats (un « ! » doré flotte au-dessus tant qu'il en reste à accepter). On les lit et on les accepte avec Entrée ; un contrat accepté passe dans le journal.
- **Contrat « Le voleur d'Eclatvin »** (pour Margot) : peu après l'avoir accepté, Pépin bouscule Zylrak sur la place et lui prend sa bourse (tous ses écus). L'enquête : Margot (des traces de pas d'enfant dans la farine ; elle donne de la viande séchée), le colporteur et la vieille voyageuse à l'étage de l'auberge, Aelis (son coussin brodé ; à la fenêtre de chez elle, des poils de chien) et Godric. Avec les cinq indices, Zylrak comprend : Pépin cache un chien dans les herbes hautes de la lisière. À la cachette, la viande séchée apprivoise Stone, des goules attaquent (Stone se bat aux côtés de Zylrak), Pépin rend la bourse, et il faut choisir :
  - **garder Stone** : il suit Zylrak sur toutes les cartes et **flaire les objets enfouis** (il court s'arrêter et aboie ; Entrée pour creuser) ;
  - **le laisser à Pépin** : ils dorment dans la grange de Margot, et Pépin offre son trésor, le **Caillou porte-bonheur**.

  Margot paie 40 écus dans les deux cas. Scènes et scripts : `scenes/maps/voleur/`, `scripts/characters/chien_compagnon.gd`, `scenes/maps/flair_chien.gd` ; choix dans les dialogues : `Cutscene.choose`.
- **Contrat « Dans le noir de la grotte »** : le forgeron confie sa torche ; au fond de la grotte du chariot, l'araignée géante garde le filon de pierre-de-braise. Rapportée à la forge, la pierre devient la **Lame de braise** (+3 en attaque), avec 30 écus. Les étapes s'affichent dans le journal, et l'objectif sur la mini-carte.
- **Le venin** : les araignées empoisonnent ; un héros empoisonné perd des PV au début de chacun de ses tours, et le venin ne part pas tout seul : il ronge encore aux combats suivants, tant que le héros n'a pas bu d'**antidote** (en combat ou depuis le grimoire ; en vente chez Myrtille, et deux dans un coffre de la grotte). Le grimoire indique qui est empoisonné.
- **Les boss** (le gardien du temple, l'araignée géante) entrent en **furie** quand ils sont bien entamés : ils attaquent alors deux fois par tour (`MonsterData.enrage_below`).
- **Les écus** : Zylrak en a 30 au départ et en gagne à chaque victoire ; ils s'affichent en bas du grimoire.
- **Nouveaux intérieurs** (`tools/make_interieurs.gd`) : la ferme-fournil de Margot (four à pain, pétrin, sacs de farine) et la chambre qu'Aelis loue.
- **La maison des jumelles** (la porte de Mirabelle) : Myrtille, sa jumelle, y vend des potions (15 écus), des fioles de mana (20 écus) et des antidotes (12 écus).

### L'auberge
Torvald, Théobald Lunebrise, Barnabé et l'inconnu encapuchonné.

À l'étage, un lit qu'Oswin loue **5 écus la nuit** (`scenes/maps/lit_auberge.gd`) : Zylrak (et Ysolde) y dorment et se réveillent avec tous leurs PV et PM, guéris du venin. Inutile de payer quand tout le monde est déjà en pleine forme.

### La forêt (au sud du village)
Trois petites cartes, reliées par les chemins (la musique continue de l'une à l'autre) :
- **La lisière** : le chemin qui descend du village, un carrefour et une prairie d'herbes hautes.
- **La cascade** (à l'ouest) : un ruisseau qui tombe de la falaise, un étang et un pont de rondins (l'eau du lac : `eau_lac.gdshader`, et la chute `chute_lac.gdshader`, qui se raccordent par une lèvre d'écume) ; le chemin de l'ouest descend vers le lac, une fois que Brenna a demandé de retrouver Aldric.
- **Le lac aux Brumes** (à l'ouest de la cascade, généré par `tools/make_lac.gd`) : un grand lac entouré de forêt, une île et son arbre mort, un ponton et sa barque, des roseaux, des nénuphars et de la brume qui dérive sur l'eau ; à l'ouest, la clairière où Aldric coupait du bois. Un panneau à l'entrée, et une tête de loup gravée dessous...
- **La quête de Brenna** (`scenes/maps/lac/`) : au lac, la clairière d'Aldric est saccagée (traces de goules, ses pas qui filent vers la rive). La barque du ponton mène à l'île, où Aldric s'est réfugié, blessé : il a vu des hommes en capuche sur la rive, qui parlaient d'un temple sous l'eau et de la lune noire. Les **goules des brumes** sortent de l'eau (combat sans fuite) ; Zylrak ramène Aldric, qui rentre au village. Brenna offre le **Ruban de Brenna** (et retient enfin le nom de Zylrak), Godric donne 30 écus.
- **Le chariot** (à l'est) : **le chariot du marchand**, renversé sur la route. Une fois la quête d'Oswin acceptée, Zylrak y trouve des indices qui mènent vers les ruines. Un sentier monte de la route jusqu'à **une grotte**, creusée dans la paroi du nord ; il faut la torche du forgeron pour y entrer. À l'est, la route mène aux ruines (une fois le chariot trouvé).
- Le vent fait doucement balancer les arbres, les buissons et les herbes, sur toutes les cartes extérieures (forêt, lac, ruines, village) : shader `vent.gdshader`, posé dans les cartes de la forêt et ajouté aux autres à l'arrivée par l'autoload `scripts/vent.gd` (les arbres du village, peints en tuiles, ont leur propre version : `vent_tuiles.gdshader`).
- Des **zones de rencontres aléatoires** partout hors de l'entrée.

### Les sons
Des bruitages partout (autoload `Sons`, `scripts/sons.gd`, fichiers dans `assets/audio/sons/`) : menus et dialogues, pas de Zylrak (selon le sol : terre, bois, pierre), une ambiance en boucle sous la musique (forêt, grotte, intérieur, cascade), portes des maisons, coffres et trouvailles, achats et écus, le chien qui aboie, la barque ; en combat, coups d'épée (le même son quand un monstre frappe), flèches, Signes, potions, cris des monstres (selon le monstre : `MonsterData.cri`), venin, furie, victoire, défaite, montée de niveau. Les combats sans fuite (gardiens, boss) ont leur propre musique, et la grotte la sienne. Le bouton du son coupe la musique et les bruitages.

### L'éclairage
Chaque carte a sa lumière (`scripts/eclairage.gd`, posé à l'arrivée sur la carte) : Eclatvin au crépuscule avec ses lanternes allumées, la forêt verte et tamisée (plus sombre autour du chariot attaqué), les ruines au couchant ; les intérieurs dans une pénombre chaude, éclairés par leurs torches, bougies, cheminées, le four de Margot, les braises de la forge et le jour des fenêtres. Les flammes vacillent (`scenes/maps/lueur.gd`). La grotte, le temple et le lac gardent leur propre éclairage. Pas de cycle jour / nuit pour l'instant.

### Les menus
- **Écran titre** au lancement : Continuer (la dernière sauvegarde), Nouvelle partie, Charger, Quitter.
- **Nouvelle partie** : une intro à l'ancienne (prologue qui s'écrit lettre par lettre sur les cartes du jeu ; Entrée pour la passer), puis Zylrak arrive au village par la route de la forêt et marche seul jusqu'à l'auberge ; coupure au noir, et Oswin lui tombe dessus.
- **La mini-carte** (touche M) : Zylrak (flèche dorée), Ysolde (point bleu), les PNJ qui ont une quête à donner (losange doré), et l'objectif des quêtes acceptées : un point vert qui pulse quand il est sur la carte, sinon une flèche verte sur la sortie qui y mène (`scripts/objectifs.gd`).
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
- Montée de niveau : Ysolde progresse avec Zylrak ; chacun a son annonce (« Niveau N ! » au-dessus de lui, puis ses gains).

### La grotte du sentier (au-dessus du chariot)
Trois salles plongées dans le noir (générées par `tools/make_grotte.gd`, tuiles du pack *Caves*), éclairées par la torche que Zylrak tient (`scenes/maps/torche_joueur.gd`) :
- **L'entrée** : stalagmites, cristaux bleus, et le jour qui entre derrière soi.
- **Le couloir aux toiles** : des toiles et des proies emmaillotées ; les araignées attaquent.
- **La salle du filon**, éclairée de rouge par la pierre-de-braise, où attend l'araignée géante (combat sans fuite, `scenes/maps/grotte_scenario.gd`).

### Les ruines des Yrenn (à l'est de la forêt)
- **La montée** : une clairière semée de ruines, une paroi rocheuse et son escalier de pierre (un panneau, à l'entrée, prévient des dangers). Ysolde y attend Zylrak, puis le suit partout.
- **Le parvis du temple** : une façade taillée au pied d'une crête, sa porte scellée à la pierre bleue, et le ciel d'aube au-dessus des sommets.
- **L'énigme de la porte** : en arrivant au parvis, Zylrak suit les traces de sang jusqu'à la porte, scellée par un voile de lumière magique. Quatre encoches attendent des pierres gravées : il faut retrouver les **quatre fragments** qui brillent dans les ruines (deux sur la montée, deux sur le parvis), puis les poser dans le bon ordre (elles sont proposées en désordre). Théobald, à l'auberge, en donne l'indice.

### Le temple des Yrenn (derrière la porte scellée)
Trois salles, de plus en plus profondes (générées par `tools/make_temple.gd`) :
- **Le vestibule** : quatre fresques murales racontent la Bête (on les lit avec Entrée, au pied du mur). Au milieu, un cercle tracé à la cendre : la flamme de l'Ordre des Cendres, renversée, peinte avec le sang du marchand.
- **La galerie** : un long couloir hanté par des goules, des zombies et des squelettes, avec une alcôve de chaque côté (l'Amulette des Yrenn, des potions).
- **La salle du gardien** : le grand cercle rituel, les sceaux au sol, des statues de mages yrenn, des torches et des braseros. Au fond, devant l'autel, se dresse le gardien, et le corps du marchand gît à côté.

**Les gardiens et les fragments d'âme.** Les Yrenn ont brisé l'âme de la Bête en quatre éclats, un par temple, et lié leurs propres âmes aux sceaux pour les garder. Sous la lune noire, l'éclat a dévoré le Yrenn qui le gardait et pris son armure ; le culte (des membres renégats de l'Ordre des Cendres) a brisé le sceau avec le sang du marchand. Zylrak doit donc vaincre le gardien corrompu (on ne peut pas fuir ce combat), puis enfermer dans la cendre la braise noire qui s'en échappe : c'était le rôle des Ashwardens, héritiers des Yrenn. Il obtient le **fragment d'âme** ; sur l'autel, le **parchemin des Yrenn** explique qu'il faut réunir les quatre et les rendre ensemble à la flamme pour resceller la Bête, et indique le prochain temple (le Loup, sous le lac). Zylrak examine le corps du marchand, puis rentre l'annoncer à Oswin, qui le récompense : la quête du marchand s'arrête là. Ysolde, elle, reste : les goules continueront de sortir de terre tant que la Bête remue, et elle s'est juré de ne plus laisser personne disparaître sous ses yeux ; elle accompagne Zylrak jusqu'au temple du Loup.

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
- Araignées : *LPC Spider* par **Stephen Challener (Redshrike)**, avec **William.Thompsonj** — CC-BY 3.0 (https://opengameart.org/content/lpc-spider).
- Zombie : *[LPC] Zombie* par **Benjamin K. Smith (BenCreating)**, commandé par castelonia, d'après la base LPC de **Stephen Challener (Redshrike)** et les animations de **Johannes Sjölund (wulax)** — CC-BY-SA 3.0 (https://opengameart.org/content/lpc-zombie).
- Musique :
  - village (*The Apothecary*), auberge (*The Tavern Keeper*), forge (*The Blacksmith*) : *Exploration Fantasy Free Pack* par **EugeneDesMusic** — licence GameDev Market (https://www.gamedevmarket.net/asset/exploration-fantasy-free-pack) ;
  - forêt (*Place_Fantasy_Desert_Loop*), lac (*Place_Lake_Loop*), grotte (*Atmosphere_Dark_Creepy_Loop*) et combats de boss (*Theme_Decisive Battle_Loop*) : *Music For Your RPG* par **The Sound Guild** — licence GameDev Market (https://www.gamedevmarket.net/asset/music-for-your-rpg) ;
  - ruines (*Sunrise Over the Ruins*) : *Emotional And Cinematic Music Pack for RPGs* par **lullemusic** — licence GameDev Market (https://www.gamedevmarket.net/asset/emotional-and-cinematic-music-pack-for-rpgs) ;
  - combats : *JRPG/RPG Combat Exploration Theme* (version en boucle) par **lardven** — licence GameDev Market (https://www.gamedevmarket.net/asset/jrpgrpg-combat-exploration-theme).
- Bruitages et ambiances :
  - *Free Fantasy SFX Pack* par **TomMusic** (https://tommusic.itch.io) : pas (terre, bois, pierre), épée, arc, sorts de feu, coffres, portes, torche, ambiances en boucle (forêt, grotte, intérieur, cascade) ;
  - *400 Sounds Pack* et *96 Extra SFX* par **Chequered Ink** (https://ci.itch.io/400-sounds-pack) : jingles au clavecin (victoire, niveau, défaite, validation), interface, livre, pièces, pelle, potion ;
  - CC0 : *Interface Sounds* par **Kenney** (dialogues) ; *80 CC0 creature SFX* et *80 CC0 RPG SFX* par **rubberduck** (cris de monstres, aboiements ; https://opengameart.org/content/80-cc0-rpg-sfx).
- Coffres : générés avec Copilot dans le style de Szadi art, puis découpés.
- Sang au sol : *Horror Fantasy Assets* par **Stealthix** — CC0 (https://opengameart.org/content/horror-fantasy-assets).
- Fonds de combat : générés avec Copilot, puis pixelisés.
- Lac : eau, rivages et décor (roseaux, nénuphars, ponton, barque, rochers, brume) générés avec Copilot ; l'herbe des rivages est rendue transparente (`tools/dev/draw_lac.gd`).
- Temple des Yrenn : fresques murales, sceaux au sol, grand cercle rituel, pierres gravées des fragments, statues de mages, ossements, racines et mousse, fond de combat de la salle, générés avec Copilot ; animations des torches et braseros, cristaux, jarres : Szadi art.
- Enseignes de l'auberge et de la forge : générées avec Copilot, puis réduites et pixelisées.
- Portraits de Margot, Myrtille, du colporteur et de la vieille voyageuse : générés avec Copilot, fond détouré par `tools/dev/import_portraits.gd`.
- Stone, le chien errant (marche, assis, renifle, aboie) : généré avec Copilot.
- Portraits d'Aldric : générés avec Copilot.
- Interface (combats et menus) :
  - cadres et contour des barres : *Tiny RPG – Mana Soul GUI* par **Gabriel « tiopalada » Lima** — CC0 (https://tiopalada.itch.io/tiny-rpg-mana-soul-gui) ;
  - remplissages des barres : Pixel UI Fantasy Free by heyheythere - https://heyheythere.itch.io/pixel-ui-fantasy-free - CC BY 4.0 ;
  - grimoire (cadre orné, parchemins, onglets, cases, barres) : *Dark Ages UI* par **Hypnobius** — usage commercial autorisé (https://hypnobius.itch.io/dark-ages-ui) ;
  - main du menu : *Hand cursor* par **andreyin** — CC0 (https://opengameart.org/node/89568).

## À venir

- Le temple du Loup, sous le lac.
