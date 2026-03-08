# 📦 Projet : Meridian — Add-on de Tracking de Nœuds de Farm WoW

> **Nom de travail :** Meridian  
> **Extension cible :** Midnight (Patch 12.0.x, 2026)  
> **Interface version :** `120001`  
> **Compatibilité Secret Values :** ✅ Non impacté (pas de données de combat)  
> **Statut :** ✅ Fonctionnel

---

## 🎯 Vision Générale

Meridian est un add-on de collecte de données de nœuds de récolte (herbes et minerais) pour le **farming de ressources** dans World of Warcraft.

Enregistrement silencieux de chaque nœud récolté (type, coordonnées, zone) dans une base de données locale exportable. Interface Glimmer Glass, stats par zone, export JSON pour Claude.

---

## 🔄 Workflow Global

```
[IN-GAME]                          [EXTERNE]
Joueur récolte           →    Export JSON des nodes
  → Node enregistré            → Coller dans Claude
  → Coordonnées + zone         → Analyse / optimisation
  → Type de ressource
  → Timestamp
```

---

## 📁 Meridian — Tracker de Nœuds

### Objectif

Accumuler silencieusement une base de données de tous les nœuds récoltés par le joueur, avec localisation précise.

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

#### Interface (Glimmer Glass)

- **Icône minimap** Glimmer pour ouvrir le panneau de stats
- **Panneau de statistiques** :
  - Deux onglets : Minerais / Herbes
  - Stats groupées par zone, zone courante mise en évidence
  - Barres glow-trail par ressource (proportionnelles au max global)
  - Bouton **"Export for Claude"** — génère le JSON dans une EditBox
- **Commandes slash** : `/mer` (toggle), `/mer export`, `/mer reset`

---

## 📤 Format d'Export

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
          "x": 38.1,
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
Voici mes données de farming WoW au format JSON.
Analyse la densité et la répartition des nœuds par zone.
[Question libre selon le besoin du moment]
```

---

## 🏗️ Architecture Technique

### Structure de fichiers — Meridian (état actuel)

```
Meridian/
├── Meridian.toc
├── Core/
│   ├── Meridian.lua           ← Init, lifecycle, commandes slash (/mer)
│   ├── Database.lua           ← Stockage nodes, queries, palette couleurs Glimmer
│   ├── Tracker.lua            ← Détection récolte (approche sandwich)
│   └── Export.lua             ← Sérialisation JSON + fenêtre d'export (EditBox)
├── UI/
│   ├── MinimapIcon.lua        ← Bouton minimap (style Glimmer)
│   └── StatsPanel.lua         ← Panneau stats Glimmer (onglets ORE/HERB, par zone)
└── locales/
    ├── enUS.lua
    └── frFR.lua
```

**Pas de librairies tierces.** AceAddon, LibStub, LibDBIcon et consorts ont été supprimés — l'addon utilise 100% l'API WoW native.

### SavedVariables

```lua
-- Une seule SavedVariable (par compte Battle.net)
MeridianDB = {
    settings = {
        minimapPos = 220,
        -- autres paramètres à venir
    },
    nodes = {
        -- Indexé par mapID → tableau séquentiel de nodes
        [2215] = {
            { itemID=12345, itemName="Midnight Herb", resourceType="HERB",
              x=45.32, y=67.18, zoneName="Quel'Thalas", timestamp=1741300000 },
        },
    },
    knownResources = {
        -- itemID → { name, resourceType, colorIndex }
        [12345] = { name="Midnight Herb", resourceType="HERB", colorIndex=1 },
    },
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

| Critère                       | Ancienne approche            | Approche sandwich                      |
| ----------------------------- | ---------------------------- | -------------------------------------- |
| ItemIDs pré-configurés        | ✅ Liste manuelle requise    | ❌ Aucune liste nécessaire             |
| Nouvelles ressources Midnight | ✅ Mise à jour manuelle      | ❌ Auto-découverte dès la 1ère récolte |
| Indépendance linguistique     | ⚠️ Mapping nom→langue requis | ✅ itemID universel extrait du lien    |
| Nom local automatique         | ❌ Non                       | ✅ Oui, dans la langue du client       |
| Fiabilité                     | ⚠️ Dépend de la liste        | ✅ Confirmé par 3 events indépendants  |

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

---

## 📊 Suivi des modifications

| Date       | Commit    | Description                                                                     |
| ---------- | --------- | ------------------------------------------------------------------------------- |
| 2026-03-07 | `f872d71` | Tracking, DB, export fonctionnels                                               |
| 2026-03-08 | —         | Design language Glimmer Glass (StatsPanel + MinimapIcon)                        |
| 2026-03-08 | —         | Export unique (Export for Claude), bouton fermer `×` Glimmer                   |
| 2026-03-08 | `b3c7096` | Stats groupées par zone — `Database:GetZoneBreakdownByType()` + headers de zone |

### État actuel (HEAD : `b3c7096`)

- ✅ Tracking automatique de tous les nœuds récoltés (herbes + minerais)
- ✅ Base de données permanente (SavedVariables `MeridianDB`)
- ✅ Export JSON pour Claude (fenêtre EditBox, copier-coller)
- ✅ Interface Glimmer Glass — transparent, sobre, verre sur le monde
- ✅ Stats groupées par zone avec mise en évidence de la zone courante
- ✅ Deux onglets : Minerais / Herbes
- ✅ Commandes slash : `/mer` (toggle), `/mer export`, `/mer reset`

### Phase 2 — À définir

_(Tu m'expliqueras ici ce qu'on va faire ensuite.)_

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
MeridianDB.knownResources = {
    [12345] = { type = "HERB", name = "Fleur de Minuit",    firstSeen = 1741300000 },
    [67890] = { type = "ORE",  name = "Minerai de Voïdite", firstSeen = 1741300050 },
    -- ... enrichi automatiquement à chaque nouvelle ressource
}
```

> 💡 Le fichier `KnownResources.lua` n'est plus nécessaire — la DB se construit en jouant.

---

## 🚀 Roadmap

### Fonctionnalités implémentées ✅

- [x] Structure du projet et .toc
- [x] Détection de récolte — approche sandwich (`Tracker.lua`)
- [x] Auto-découverte et enregistrement des ressources (`Database.lua`)
- [x] Enregistrement des coordonnées (`Database.lua`)
- [x] Interface Glimmer Glass (`StatsPanel.lua`) — stats par zone, deux onglets
- [x] Icône minimap Glimmer (`MinimapIcon.lua`)
- [x] Export JSON pour Claude (`Export.lua`)

### Prochaines étapes

> À définir.

---

## ⚙️ Configuration Utilisateur

```lua
local defaults = {
    profile = {
        enabled = true,
        tracking = {
            trackHerbs = true,
            trackOres = true,
        },
        minimap = { hide = false },
    }
}
```

---

## 🎨 Identité Visuelle — Glimmer Glass

Voir la section dédiée dans `agentwow.md`. Règle : toute nouvelle frame respecte le design language Glimmer sans exception.

- **Palette ressources** : 8 couleurs désaturées (mint, ambre, ciel, rose, lavande, teal, or, rose poudré)
- **Fond** : `SetColorTexture(0.02, 0.02, 0.03, 0.68)` — verre sur le monde
- **Pas de** `BackdropTemplate`, pas de chrome WoW, pas de fond coloré

---

## 📝 Notes et Contraintes

1. **Secret Values** : Ce projet est **100% compatible** avec les restrictions Midnight — aucune donnée de combat n'est utilisée. Toute la détection se fait hors-combat (récolte).

2. **Performance** : La base de données peut grossir rapidement (200+ nodes × N ressources × M zones). Prévoir une **pagination** ou un système d'**archivage par zone** pour éviter un SavedVariables trop lourd.

3. **Export** : WoW ne peut pas écrire directement sur le disque. L'export passe par une **EditBox** dont le contenu est copié manuellement par le joueur (comportement standard pour tous les addons d'export WoW).

4. **Compatibilité Classic** : Hors scope pour l'instant. Les ItemIDs des ressources sont différents entre Retail et Classic.

---

_Brief de projet rédigé le 07/03/2026 — À utiliser conjointement avec `agent.md` pour le développement._
