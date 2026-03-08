# 📦 Projet : Meridian — Add-on de Tracking de Nœuds de Farm WoW

> **Nom de travail :** Meridian  
> **Extension cible :** Midnight (Patch 12.0.x, 2026)  
> **Interface version :** `120001`  
> **Compatibilité Secret Values :** ✅ Non impacté (pas de données de combat)  
> **Statut :** ✅ Fonctionnel

---

## 🎯 Vision Générale

Meridian est un add-on de collecte et d'analyse de nœuds de récolte (herbes et minerais) pour le **farming de ressources** dans World of Warcraft.

**Différentiel vs GatherMate/Wowhead :** ces outils se basent sur les spawn points théoriques. Meridian collecte des données **réelles** — uniquement les ressources effectivement récoltées, filtrées naturellement (zones élites, packs de mobs, accès difficiles ignorés).

**Vision finale (Phase 2) :** tu ouvres WoW, tu scannes l'HV avec Auctionator, Meridian croise les prix et ta densité de nœuds et te dit : _"Cette session, va dans Arandar."_ Zéro réflexion, farming optimisé entre deux arènes.

---

## 🔄 Workflow Global

```
[PHASE 1 — Collecte]                 [EXTERNE]
Joueur récolte           →    Export JSON des nodes
  → Node enregistré            → Coller dans Claude
  → Coordonnées + zone         → Analyse densité par zone
  → Timestamp

[PHASE 2 — Oracle]
Joueur ouvre l'HV        →    Scan Auctionator (habituel)
  → Meridian lit les prix      → Oracle : prix × densité → score
  → Recommandation de zone     →  "Cette session : Arandar"
```

---

## 📁 Meridian — Tracker de Nœuds

**Détection :** événements `PLAYER_TARGET_CHANGED` → `UNIT_SPELLCAST_SUCCEEDED` → `CHAT_MSG_LOOT` (approche sandwich). ItemID extrait du lien WoW — universel, indépendant de la langue. Aucune liste pré-remplie nécessaire.

**Enregistrement :** coordonnées via `C_Map.GetBestMapForUnit` + `C_Map.GetPlayerMapPosition`, indexées par `mapID`.

**Interface :** Glimmer Glass (voir `agentwow.md`) — deux onglets ORE/HERB, stats groupées par zone, zone courante mise en évidence, bouton Export for Claude.

**Commandes slash :** `/mer` (toggle), `/mer export`, `/mer reset`

**Structure d'un node :**

````lua
{ itemID=12345, itemName="Midnight Herb", resourceType="HERB",
  mapID=2215, zoneName="Quel'Thalas", subZone="Silvermoon",
  x=45.32, y=67.18, timestamp=1741300000 }

---

## 📤 Format d'Export (JSON → Claude)

```json
{
  "export_version": "1.0",
  "wow_patch": "12.0.1",
  "zones": {
    "2215": {
      "zone_name": "Quel'Thalas",
      "nodes": [
        { "item_id": 12345, "item_name_local": "Herbe de Minuit",
          "resource_type": "HERB", "x": 45.32, "y": 67.18,
          "sub_zone": "Silvermoon City", "timestamp": 1741300000 }
      ],
      "summary": { "total_nodes": 1,
        "by_resource": { "12345": { "name": "Midnight Herb", "type": "HERB", "count": 1 } }
      }
    }
  }
}
````

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

**Pas de librairies tierces.** API WoW native uniquement.

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

## Suivi des modifications

| Date       | Commit    | Description                                                                     |
| ---------- | --------- | ------------------------------------------------------------------------------- |
| 2026-03-07 | `f872d71` | Tracking, DB, export fonctionnels                                               |
| 2026-03-08 | —         | Design language Glimmer Glass (StatsPanel + MinimapIcon)                        |
| 2026-03-08 | —         | Export unique (Export for Claude), bouton fermer `×` Glimmer                    |
| 2026-03-08 | `b3c7096` | Stats groupées par zone — `Database:GetZoneBreakdownByType()` + headers de zone |
| 2026-03-08 | `16fb580` | Docs : optimisation contexte agent (agentwow 1039→240, projetwow 370→112)       |
| 2026-03-08 | —         | Vision Phase 2 documentée : Oracle de farming (prix HV × densité nœuds)         |

---

## 🔌 Dépendances

| Add-on          | Rôle                                    | Requis pour               |
| --------------- | --------------------------------------- | ------------------------- |
| **Auctionator** | Prix HV locaux via `Auctionator.API.v1` | Phase 2 Oracle uniquement |

Sans Auctionator installé et à jour, l'Oracle affiche "Auctionator requis" — la Phase 1 fonctionne normalement sans aucune dépendance.

---

## 🔮 Phase 2 — Oracle de Farming

**Objectif :** Recommander la meilleure zone de farming au login, en croisant les prix HV actuels et la densité de nœuds collectée en Phase 1.

### Fonctionnement

1. Tu fais ton scan Auctionator habituel à l'hôtel des ventes
2. Meridian lit les prix via `Auctionator.API.v1.GetAuctionPriceByItemID("Meridian", itemID)`
3. Oracle calcule : `score_zone = Σ (prix × nb_noeuds_par_item_dans_zone)`
4. Recommandation affichée : _"Meilleure zone : Arandar | ORE: Midnight Iron | HERB: Moonbloom"_

### Nouveaux fichiers (Phase 2)

```
Core/Oracle.lua         ← Calcul score par zone (prix × densité de nœuds)
UI/OracleWidget.lua     ← Widget Glimmer — recommandation affichée en permanence
```

### Extension SavedVariables

```lua
MeridianDB.prices = {
    -- itemID → { price (cuivres), quantity, timestamp }
    [12345] = { price = 28000, quantity = 47, timestamp = 1741300000 },
}
```

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

---

_À utiliser conjointement avec `agentwow.md`._
