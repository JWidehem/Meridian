# 📦 Projet : GatherMap — Add-on de Tracking & Routes de Farm WoW

> **Nom de travail :** GatherMap  
> **Extension cible :** Midnight (Patch 12.0.x, 2026)  
> **Interface version :** `120001`  
> **Compatibilité Secret Values :** ✅ Non impacté (pas de données de combat)  
> **Phases :** 2 (Data Collection → Route Display)

---

## 🎯 Vision Générale

GatherMap est un add-on de collecte de données et d'affichage de routes optimisées pour le **farming de ressources** (herbes et minerais) dans World of Warcraft.

Le projet se déroule en **deux phases distinctes** :

1. **Phase 1 — GatherMap Tracker** : Enregistrer silencieusement chaque nœud récolté (type, coordonnées, zone) dans une base de données locale exportable.
2. **Phase 2 — GatherMap Routes** : Afficher des routes optimisées sur la minimap et guider le joueur via une flèche de navigation (style TomTom), à partir soit des données collectées, soit de routes pré-calculées par IA.

---

## 🔄 Workflow Global

```
[PHASE 1]                          [EXTERNE]                        [PHASE 2]
Joueur récolte           →    Export JSON/CSV des nodes    →    IA dessine la route
  → Node enregistré            + Screenshot de la zone          → Route importée
  → Coordonnées + zone         → IA génère la route optimale    → Affichage minimap
  → Type de ressource          → Route exportée (waypoints)     → Flèche de guidage
  → Timestamp                                                    → Filtrage par ressource
```

---

## 📁 PHASE 1 — GatherMap Tracker

### Objectif
Accumuler silencieusement une base de données de tous les nœuds récoltés par le joueur, avec localisation précise, pour atteindre un seuil statistiquement exploitable (~200 nodes par ressource par zone).

### Fonctionnalités

#### Détection automatique de la récolte
- Écoute l'événement `UNIT_SPELLCAST_SUCCEEDED` combiné à `LOOT_CLOSED` pour détecter une récolte réussie
- Alternative : hook sur `BAG_UPDATE_DELAYED` + détection de l'item obtenu (herbalism/mining)
- Identification du type de ressource via l'item looté (en cross-référençant `C_Item.GetItemInfo`)
- **Totalement indépendant des Secret Values** : aucune donnée de combat impliquée

#### Enregistrement des coordonnées
- Utilisation de `C_Map.GetPlayerMapPosition(mapID, "player")` pour obtenir les coordonnées X/Y (0.0–1.0)
- Conversion en coordonnées carte affichables (×100 pour obtenir le format XX.XX)
- Enregistrement du `mapID` (identifiant de zone Blizzard) + nom de zone lisible via `C_Map.GetMapInfo(mapID)`
- Enregistrement du `subZone` via `GetSubZoneText()` pour plus de précision

#### Indépendance linguistique
- L'identification de la ressource se fait par **ItemID** (identifiant numérique universel), pas par le nom affiché
- Le nom est récupéré via `C_Item.GetItemInfo(itemID)` dans la langue du client, mais stocké avec l'ItemID comme clé primaire
- Un mapping `ItemID → type` (HERB / ORE) et `ItemID → nom_canonique_enUS` est maintenu en interne
- Fonctionne identiquement en français, anglais, allemand, etc.

#### Structure de la base de données interne
Chaque node enregistré contient :
```lua
{
    itemID       = 12345,          -- Identifiant universel de la ressource
    itemName     = "Nom local",    -- Nom dans la langue du client (pour affichage)
    resourceType = "HERB",         -- "HERB" ou "ORE"
    mapID        = 2215,           -- ID de la zone Blizzard
    zoneName     = "Quel'Thalas",  -- Nom de la zone (langue client)
    subZone      = "Silvermoon",   -- Sous-zone
    x            = 45.32,          -- Coordonnée X (format carte, 0–100)
    y            = 67.18,          -- Coordonnée Y (format carte, 0–100)
    timestamp    = 1741300000,     -- Unix timestamp de la récolte
    count        = 1,              -- Nombre d'items récoltés (pour stats)
}
```

#### Interface de suivi (minimale, Phase 1)
- **Icône minimap** (via LibDBIcon-1.0) pour ouvrir le panneau de stats
- **Panneau de statistiques** simple :
  - Nombre de nodes enregistrés par ressource
  - Nombre de nodes par zone
  - Barre de progression vers le seuil d'export (ex: 200 nodes par ressource)
  - Bouton **"Exporter"** pour générer le fichier de données
- **Commande slash** : `/gathermap` ou `/gm`

#### Seuils d'export configurables
```
Seuil par défaut : 200 nodes par ressource par zone
Configurable via l'interface : 50 / 100 / 200 / 500 / custom
```
Quand le seuil est atteint pour une ressource dans une zone, une notification discrète s'affiche.

---

## 📤 Format d'Export (Phase 1 → IA)

L'export doit être **directement lisible par une IA** (Claude, GPT, etc.) et exploitable pour générer des routes optimisées.

### Format JSON (principal)
```json
{
  "export_version": "1.0",
  "addon_version": "1.0.0",
  "export_date": "2026-03-07T14:32:00Z",
  "wow_patch": "12.0.1",
  "zones": {
    "2215": {
      "zone_name": "Quel'Thalas",
      "map_id": 2215,
      "nodes": [
        {
          "id": 1,
          "item_id": 12345,
          "item_name_local": "Herbe de Minuit",
          "item_name_enUS": "Midnight Herb",
          "resource_type": "HERB",
          "x": 45.32,
          "y": 67.18,
          "sub_zone": "Silvermoon City",
          "timestamp": 1741300000,
          "count": 1
        },
        {
          "id": 2,
          "item_id": 67890,
          "item_name_local": "Voidstone Ore",
          "item_name_enUS": "Voidstone Ore",
          "resource_type": "ORE",
          "x": 38.10,
          "y": 55.44,
          "sub_zone": "Eversong Woods",
          "timestamp": 1741300120,
          "count": 3
        }
      ],
      "summary": {
        "total_nodes": 2,
        "by_resource": {
          "12345": { "name": "Midnight Herb", "type": "HERB", "count": 1 },
          "67890": { "name": "Voidstone Ore", "type": "ORE", "count": 1 }
        }
      }
    }
  }
}
```

### Format CSV (alternatif, pour tableurs)
```csv
zone_id,zone_name,item_id,item_name_enUS,resource_type,x,y,sub_zone,timestamp,count
2215,Quel'Thalas,12345,Midnight Herb,HERB,45.32,67.18,Silvermoon,1741300000,1
2215,Quel'Thalas,67890,Voidstone Ore,ORE,38.10,55.44,Eversong Woods,1741300120,3
```

### Prompt IA recommandé (à fournir avec l'export)
```
Voici mes données de farming WoW au format JSON, accompagnées d'un screenshot 
de la zone [NOM_ZONE].

Génère une route optimisée de farming pour [RESSOURCE / TOUTES LES HERBES / 
TOUS LES MINERAIS / TOUT] en tenant compte de :
- La densité de nodes par zone de la carte
- Un parcours en boucle fermée (départ = arrivée)
- L'évitement des zones sans nodes
- La priorité aux clusters de nodes denses

Retourne la route sous forme d'une liste ordonnée de waypoints 
{ "order": N, "x": XX.XX, "y": XX.XX, "note": "..." } 
que je pourrai importer dans mon add-on WoW.
```

---

## 🗺️ PHASE 2 — GatherMap Routes

### Objectif
Afficher des routes de farming optimisées directement dans le jeu, en guidant le joueur waypoint par waypoint, avec possibilité de filtrer par ressource.

### Fonctionnalités

#### Système de routes
- **Import de routes** : Coller une liste de waypoints JSON dans l'interface (généré par l'IA)
- **Routes sauvegardées** : Une route = un profil nommé (ex: "Quel'Thalas - Herbes", "Quel'Thalas - Tout")
- **Filtrage des routes** par :
  - Une ressource spécifique (ex: "Midnight Herb uniquement")
  - Toutes les herbes
  - Tous les minerais
  - Herbes + minerais combinés
- **Activation/désactivation** en un clic depuis l'icône minimap

#### Affichage sur la minimap
- Tracé de la route sur la minimap avec des **icônes de nodes** (herbe = vert, minerai = jaune/orange)
- **Waypoint actif** mis en surbrillance
- **Lignes de connexion** entre les waypoints pour visualiser le parcours
- Respect du style visuel WoW (pas de frames intrusives)

#### Navigation — Flèche de guidage
Deux options (configurables) :

**Option A — Intégration TomTom (recommandé si l'utilisateur a TomTom installé)**
```lua
-- Détection de TomTom et ajout de waypoints
if TomTom then
    TomTom:AddWaypoint(mapID, x/100, y/100, {
        title = "GatherMap: " .. nodeName,
        persistent = false,
        minimap = true,
        world = true,
    })
end
```

**Option B — Flèche native GatherMap (si TomTom absent)**
- Frame custom avec une **texture de flèche** positionnée au centre de l'écran (ou au-dessus de l'action bar)
- La flèche pointe vers le prochain waypoint
- Calcul de l'angle via `C_Map.GetPlayerMapPosition` + trigonométrie simple
- Distance affichée sous la flèche (en yards via `C_Map` ou estimation)
- La flèche tourne en temps réel selon la direction du joueur

#### Progression automatique des waypoints
- Quand le joueur arrive dans un rayon de **~10 yards** du waypoint actuel → passage automatique au suivant
- Si une récolte est détectée sur le waypoint → marquage comme "visité" (icône grisée sur minimap)
- Bouton **"Passer"** pour sauter manuellement un waypoint
- Bouton **"Recommencer la boucle"** pour repartir du début

#### Interface Principale (Phase 2)
```
┌─────────────────────────────────┐
│  🌿 GatherMap Routes            │
├─────────────────────────────────┤
│  Zone : Quel'Thalas             │
│                                 │
│  Filtre :                       │
│  ○ Toutes les herbes            │
│  ○ Tous les minerais            │
│  ● Tout (herbes + minerais)     │
│  ○ Ressource spécifique : [▼]   │
│                                 │
│  Route : [Quel'Thalas - Tout ▼] │
│  Waypoints : 47 | Restants : 23 │
│                                 │
│  [▶ Démarrer]  [⏸ Pause]  [⏹]  │
│  [Importer route] [Gérer routes]│
└─────────────────────────────────┘
```

#### Optimisation performance (Phase 2)
- Les routes sont stockées sous forme de **waypoints pré-calculés** uniquement (pas les données brutes de nodes)
- Une fois une route importée et sauvegardée, les données sources (200+ nodes) peuvent être **archivées ou supprimées** pour libérer de la mémoire
- Structure d'une route sauvegardée :
```lua
{
    name = "Quel'Thalas - Tout",
    mapID = 2215,
    filter = "ALL",           -- "ALL", "HERB", "ORE", "SPECIFIC:12345"
    created = 1741300000,
    waypoints = {
        { order = 1, x = 45.32, y = 67.18, label = "Midnight Herb", type = "HERB" },
        { order = 2, x = 38.10, y = 55.44, label = "Voidstone Ore", type = "ORE" },
        -- ...
    }
}
```

---

## 🏗️ Architecture Technique

### Structure de fichiers (Phase 1)
```
GatherMap/
├── GatherMap.toc
├── Core/
│   ├── GatherMap.lua          ← Init, lifecycle, commandes slash
│   ├── Tracker.lua            ← Détection et enregistrement des nodes
│   ├── Database.lua           ← Gestion de la base de données locale
│   └── Export.lua             ← Génération du JSON/CSV exportable
├── UI/
│   ├── MinimapIcon.lua        ← Icône minimap (LibDBIcon)
│   └── StatsPanel.lua         ← Panneau de statistiques et bouton export
├── Data/
│   └── KnownResources.lua     ← Mapping ItemID → type/nom canonique
├── libs/
│   ├── LibStub/
│   ├── AceAddon-3.0/
│   ├── AceDB-3.0/
│   ├── AceConsole-3.0/
│   ├── AceEvent-3.0/
│   ├── LibDataBroker-1.1/
│   └── LibDBIcon-1.0/
├── locales/
│   ├── enUS.lua
│   └── frFR.lua
└── GatherMap.toc
```

### Structure de fichiers (Phase 2, ajouts)
```
GatherMap/
├── Core/
│   └── RouteEngine.lua        ← Gestion des routes, progression waypoints
├── UI/
│   ├── RoutePanel.lua         ← Interface principale Phase 2
│   ├── MinimapDrawer.lua      ← Tracé des routes sur la minimap
│   └── NavigationArrow.lua    ← Flèche de guidage (si pas TomTom)
└── Data/
    └── Routes/                ← Routes sauvegardées (JSON importés)
```

### SavedVariables
```lua
-- Données Phase 1 (brutes, volumineuses)
GatherMapDB = {
    nodes = { ... }       -- Tous les nodes enregistrés
    settings = { ... }    -- Paramètres utilisateur
    stats = { ... }       -- Statistiques de session
}

-- Données Phase 2 (légères, permanentes)
GatherMapRoutesDB = {
    routes = { ... }      -- Routes pré-calculées importées
    activeRoute = nil     -- Route actuellement active
    settings = { ... }
}
```

---

## 🔧 Détails Techniques Clés

### Détection de récolte — Approche "sandwich" (100% automatique)

Tout est capturé automatiquement sans aucune liste pré-remplie. Trois événements WoW se déclenchent naturellement à chaque récolte, dans cet ordre :

```
[1] PLAYER_TARGET_CHANGED   → Le nœud est ciblé au clic
[2] UNIT_SPELLCAST_SUCCEEDED → Le sort de récolte se termine
[3] CHAT_MSG_LOOT            → L'item obtenu apparaît dans le chat
```

```lua
-- ============================================================
-- ÉTAPE 1 : Ciblage du nœud (PLAYER_TARGET_CHANGED)
-- ============================================================
-- Quand le joueur clique sur un nœud, il le cible.
-- On enregistre le nom du nœud ET les coordonnées à ce moment précis
-- (le joueur est pile dessus).

local pendingNode = nil  -- stockage temporaire entre les 3 events

local function OnTargetChanged()
    local targetName = UnitName("target")
    if not targetName then return end
    -- On note le nom du nœud + les coordonnées actuelles
    -- La confirmation viendra via UNIT_SPELLCAST_SUCCEEDED
    pendingNode = {
        nodeName = targetName,
        coords    = GetPlayerCoords(),  -- fonction définie plus bas
    }
end

-- ============================================================
-- ÉTAPE 2 : Confirmation de la récolte (UNIT_SPELLCAST_SUCCEEDED)
-- ============================================================
-- Sorts de récolte connus (IDs stables entre expansions)
-- La liste se complète avec les nouveaux sorts Midnight au fil du jeu
local GATHER_SPELLS = {
    -- Herbalism
    [2366]  = "HERB",  [2368]  = "HERB",  [197919] = "HERB",
    [229079]= "HERB",  [269740]= "HERB",  [311984] = "HERB",
    -- Mining
    [818]   = "ORE",   [32606] = "ORE",   [193958] = "ORE",
    [281887]= "ORE",   [311984]= "ORE",
    -- Note : /run print(IsSpellKnown(X)) pour vérifier les IDs Midnight
}

local function OnSpellCastSucceeded(event, unit, castGUID, spellID)
    if unit ~= "player" then return end
    local resourceType = GATHER_SPELLS[spellID]
    if not resourceType or not pendingNode then return end
    -- ✅ Confirmé : c'est bien une récolte herb/ore
    pendingNode.resourceType = resourceType
    pendingNode.spellID = spellID
    -- Les coords sont déjà dans pendingNode depuis PLAYER_TARGET_CHANGED
end

-- ============================================================
-- ÉTAPE 3 : Capture de l'ItemID (CHAT_MSG_LOOT)
-- ============================================================
-- Le message de loot contient l'item link WoW :
-- Format : "|Hitem:ITEMID:0:0:...|h[Nom affiché]|h"
-- L'ITEMID est universel (même nombre en FR, EN, DE, etc.)
-- Le nom affiché est AUTOMATIQUEMENT dans la langue du client

local function ExtractFromItemLink(itemLink)
    -- Extraction de l'itemID depuis le lien WoW (format universel)
    local itemID = tonumber(itemLink:match("|Hitem:(%d+):"))
    -- Extraction du nom local (entre crochets)
    local itemName = itemLink:match("|h%[(.-)%]|h")
    return itemID, itemName
end

local function OnChatMsgLoot(event, msg)
    if not pendingNode or not pendingNode.resourceType then return end

    -- Chercher un item link dans le message de loot
    local itemLink = msg:match("|H(item:[^|]+)|h")
    if not itemLink then return end

    local itemID, itemName = ExtractFromItemLink("|H" .. itemLink .. "|h")
    if not itemID then return end

    -- Vérification optionnelle via la sous-classe de l'item
    -- C_Item.GetItemSubClassInfo() confirme si c'est une herbe ou un minerai
    -- (universel, indépendant de la langue)

    -- ✅ On a TOUT : on enregistre le node
    GatherMap:RecordNode({
        itemID       = itemID,
        itemName     = itemName,         -- Nom dans LA langue du joueur, auto
        nodeName     = pendingNode.nodeName,
        resourceType = pendingNode.resourceType,  -- "HERB" ou "ORE"
        mapID        = pendingNode.coords.mapID,
        zoneName     = pendingNode.coords.zoneName,
        subZone      = pendingNode.coords.subZone,
        x            = pendingNode.coords.x,
        y            = pendingNode.coords.y,
        timestamp    = time(),
    })

    pendingNode = nil  -- reset pour la prochaine récolte
end
```

### Pourquoi cette approche est supérieure

| Critère | Ancienne approche | Approche sandwich |
|---------|------------------|-------------------|
| ItemIDs pré-configurés | ✅ Liste manuelle requise | ❌ Aucune liste nécessaire |
| Nouvelles ressources Midnight | ✅ Mise à jour manuelle | ❌ Auto-découverte dès la 1ère récolte |
| Indépendance linguistique | ⚠️ Mapping nom→langue requis | ✅ itemID universel extrait du lien |
| Nom local automatique | ❌ Non | ✅ Oui, dans la langue du client |
| Fiabilité | ⚠️ Dépend de la liste | ✅ Confirmé par 3 events indépendants |

### Coordonnées et conversion

```lua
-- Obtenir les coordonnées du joueur
local function GetPlayerCoords()
    local mapID = C_Map.GetBestMapForUnit("player")
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return nil end
    return {
        mapID = mapID,
        x = math.floor(pos.x * 10000 + 0.5) / 100,  -- Ex: 0.4532 → 45.32
        y = math.floor(pos.y * 10000 + 0.5) / 100,  -- Ex: 0.6718 → 67.18
        zoneName = C_Map.GetMapInfo(mapID).name,
        subZone = GetSubZoneText(),
    }
end
```

### Export JSON depuis Lua

```lua
-- WoW n'a pas de librairie JSON native → sérialisation manuelle ou via AceSerializer
-- Option recommandée : sérialisation manuelle simple pour la Phase 1
local function TableToJSON(t, indent)
    -- Implémentation légère pour notre format de données connu
    -- (structure fixe → pas besoin d'un parser générique complet)
end

-- Pour copier dans le clipboard et coller dans un fichier :
-- Afficher dans une ScrollFrame éditable → le joueur fait Ctrl+A, Ctrl+C
local exportFrame = CreateFrame("EditBox", ...)
exportFrame:SetText(jsonString)
exportFrame:HighlightText()
-- → Le joueur copie le contenu et le colle dans un fichier .json
```

---

## 📋 Auto-découverte des Ressources (Midnight 12.0.x)

> ✅ **Aucune liste manuelle requise.** L'addon apprend automatiquement chaque ressource à la première récolte grâce à l'approche "sandwich" (voir section Détails Techniques).

### Fonctionnement de l'auto-découverte
1. **Première récolte** d'une herbe ou d'un minerai → l'addon extrait l'`itemID` et le nom local depuis le lien WoW
2. **Stockage automatique** dans `GatherMapDB.knownResources[itemID]` avec le type (HERB/ORE) et le nom
3. **Dès la 2ème récolte** du même item → reconnaissance instantanée, pas de re-découverte

```lua
-- Exemple de ce que la base apprend toute seule après quelques récoltes :
GatherMapDB.knownResources = {
    [12345] = { type = "HERB", name = "Fleur de Minuit",    firstSeen = 1741300000 },
    [67890] = { type = "ORE",  name = "Minerai de Voïdite", firstSeen = 1741300050 },
    -- ... enrichi automatiquement à chaque nouvelle ressource
}
```

> 💡 Le fichier `KnownResources.lua` n'est plus nécessaire — la DB se construit en jouant. Cependant, on peut optionnellement l'exporter et le partager avec la communauté.

---

## 🚀 Roadmap de Développement

### Phase 1 — MVP Tracker (Priorité haute)
- [x] Structure du projet et .toc
- [ ] Système de détection de récolte — approche sandwich (`Tracker.lua`)
- [ ] Auto-découverte et enregistrement des ressources (`Database.lua`)
- [ ] Enregistrement des coordonnées (`Database.lua`)
- [ ] Interface de stats simple (`StatsPanel.lua`)
- [ ] Icône minimap (`MinimapIcon.lua`)
- [ ] Export JSON/CSV (`Export.lua`)
- [ ] Tests sur les zones de Midnight

### Phase 2 — Routes & Navigation
- [ ] Moteur de routes (`RouteEngine.lua`)
- [ ] Import de routes (UI + parser JSON)
- [ ] Tracé minimap (`MinimapDrawer.lua`)
- [ ] Intégration TomTom (optionnelle)
- [ ] Flèche de navigation native (`NavigationArrow.lua`)
- [ ] Filtrage par ressource
- [ ] Sauvegarde et gestion des routes
- [ ] Nettoyage/archivage des données brutes

### Futur (Phase 3 — optionnel)
- [ ] Partage de routes entre joueurs via addon messages
- [ ] Statistiques de farming (items/heure par route)
- [ ] Heatmap de densité sur la minimap (Phase 1 enrichie)
- [ ] Export direct vers wago.io ou site dédié

---

## ⚙️ Configuration Utilisateur

```lua
local defaults = {
    profile = {
        -- Phase 1
        enabled = true,
        tracking = {
            trackHerbs = true,
            trackOres = true,
            exportThreshold = 200,    -- nodes avant notification d'export
            exportFormat = "JSON",    -- "JSON" ou "CSV"
        },
        -- Phase 2
        navigation = {
            useTomTom = true,         -- Priorité à TomTom si installé
            showArrow = true,         -- Flèche native (si pas TomTom)
            arrowSize = 64,           -- Taille en pixels
            arrowAlpha = 0.9,
            arrowPosition = "CENTER", -- "CENTER", "BOTTOM"
            arrivalRadius = 10,       -- Yards pour valider un waypoint
            showMinimapLine = true,
            minimapLineColor = { r=0.2, g=1.0, b=0.4, a=0.8 },
        },
        -- UI
        minimap = { hide = false },
    }
}
```

---

## 🎨 Identité Visuelle

- **Couleurs** :
  - Herbes : `#2ECC71` (vert émeraude)
  - Minerais : `#F39C12` (orange/doré)
  - Route active : `#3498DB` (bleu)
  - Waypoint visité : `#95A5A6` (gris)
- **Icônes** : Utiliser les textures WoW existantes (`Interface\Icons\...`) pour herbes et minerais
- **Style** : Sobre, non-intrusif, s'intègre à l'UI Blizzard par défaut

---

## 📝 Notes et Contraintes

1. **Secret Values** : Ce projet est **100% compatible** avec les restrictions Midnight — aucune donnée de combat n'est utilisée. Toute la détection se fait hors-combat (récolte).

2. **Performance** : La base de données peut grossir rapidement (200+ nodes × N ressources × M zones). Prévoir une **pagination** ou un système d'**archivage par zone** pour éviter un SavedVariables trop lourd.

3. **Export** : WoW ne peut pas écrire directement sur le disque. L'export passe par une **EditBox** dont le contenu est copié manuellement par le joueur (comportement standard pour tous les addons d'export WoW).

4. **TomTom** : Déclaré en `OptionalDeps` dans le .toc. Si absent, le système natif prend le relais automatiquement.

5. **Compatibilité Classic** : Hors scope pour l'instant. Les ItemIDs des ressources sont différents entre Retail et Classic.

6. **Données partagées** : Les routes finales peuvent être distribuées sous forme de strings importables (comme les WeakAuras strings), permettant à la communauté de partager des routes optimisées.

---

*Brief de projet rédigé le 07/03/2026 — À utiliser conjointement avec `agent.md` pour le développement.*
