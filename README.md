# kq_ymap_exporter

Ressource FiveM permettant d'exporter les props posés avec **kq_propplacer** vers un fichier `.ymap.xml` prêt à être ouvert dans CodeWalker et streamé sur un serveur GTA V / FiveM.

---

## Fonctionnalités

- Export de tous les props de la base de données `kq_propplacer` en un seul fichier `.ymap.xml`
- Nommage du fichier à la demande via commande ingame
- Calcul automatique des `streamingExtents` et `entitiesExtents`
- Conversion automatique des rotations Euler → Quaternion (format requis par le ymap)
- Proposition de vider le prop placer après export, avec confirmation obligatoire
- Système de permissions via ACE

---

## Dépendances

- [oxmysql](https://github.com/overextended/oxmysql)
- [kq_propplacer](https://github.com/Kiminaze/kq_propplacer)

---

## Installation

1. Télécharger ou cloner le dépôt dans ton dossier `resources`
2. Créer le dossier `exports/` à l'intérieur de la ressource
3. Ajouter dans `server.cfg` :

```
ensure kq_ymap_exporter
add_ace group.admin command.exportymap allow
```

> `kq_ymap_exporter` doit démarrer **après** `oxmysql`.

---

## Configuration

Tout se règle dans le bloc `CONFIG` en haut de `server.lua` :

| Clé | Défaut | Description |
|---|---|---|
| `outputDir` | `"exports/"` | Dossier de sortie (relatif à la ressource) |
| `streamMargin` | `200.0` | Marge ajoutée aux streamingExtents |
| `defaultLodDist` | `200` | Valeur lodDist de chaque entité |
| `acePermission` | `"command.exportymap"` | Permission ACE requise (`""` = tout le monde) |
| `propPlacerResource` | `"kq_propplacer"` | Nom exact de la ressource prop placer |

---

## Utilisation

### Exporter les props

```
/exportymap
```
Le script demande le nom du fichier.

```
/exportymap <nom>
```
Lance directement l'export avec le nom fourni.

Le fichier est généré dans `kq_ymap_exporter/exports/<nom>.ymap.xml`.

### Après l'export — vider le prop placer

Une fois l'export réussi, le script propose automatiquement de vider la base de données :

```
/ymapconfirm   → supprime toutes les entrées de kq_propplacer + restart la ressource
/ymapcancel    → annule, les données sont conservées
```

> ⚠️ **Important** : ne pas streamer le fichier `.ymap.xml` exporté tant que le prop placer contient encore les mêmes props — les objets apparaîtraient en double en jeu.

---

## Workflow recommandé

```
1. /exportymap ma_carte
2. Ouvrir ma_carte.ymap.xml dans CodeWalker pour vérifier
3. /ymapconfirm  (vide la DB + despawn les props en jeu)
4. Placer le .ymap.xml dans ton dossier stream
```

---

## Structure

```
kq_ymap_exporter/
├── fxmanifest.lua
├── server.lua
├── exports/          ← fichiers .ymap.xml générés
└── README.md
```

---

## Licence

MIT
