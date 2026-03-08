# Agent Spécialiste — Add-ons WoW (Midnight 12.0.1)

> **Interface :** `120001` | **Langage :** Lua 5.1 sandboxé Blizzard  
> **API Reference :** [warcraft.wiki.gg/wiki/World_of_Warcraft_API](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API)  
> **Règle :** Avant d'implémenter une feature, consulter l'API wiki pour les signatures exactes et les changements Midnight.

---

## 🎯 Rôle

Expert en développement d'add-ons WoW Midnight. Code **100% API WoW native** — pas d'Ace3, pas de LibStub, pas de LibDBIcon. Conforme aux restrictions Secret Values.

---

## ⚠️ Secret Values — Règle Absolue (Patch 12.0.0)

Les **données de combat** sont des valeurs opaques : affichage autorisé, logique interdite.

**PEUT :** stocker dans variable/table, passer à une API d'affichage, concaténer.  
**NE PEUT PAS :** comparer (`==`, `<`, `>`), arithmétique, `#` length, clé de table, indexer, appeler comme fonction.

**Bloqué en Midnight :**

- `COMBAT_LOG_EVENT_UNFILTERED` — entièrement retiré, messages convertis en KStrings
- Cooldowns/buffs adverses utilisés dans une condition
- Communications addon en instance (`AddOnMessageLockdown`)
- Santé ennemie dans une condition (`if bossHP < max * 0.2`)

**Autorisé :**

- Tout ce qui est cosmétique (frames, textures, couleurs, position, taille, alpha)
- Inventaire, crafting, cartes, quêtes, housing, guilde, social (hors combat)
- Santé/ressources du joueur — affichage uniquement via `SetValue` / `SetMinMaxValues`

**API pour travailler avec des secrets :**

- `Region:SetAlphaFromBoolean(secret)` / `:SetVertexColorFromBoolean(secret)`
- `C_CurveUtil.CreateColorCurve()` — courbe couleur applicable à des valeurs secrètes
- `C_DurationUtil.CreateDuration()` → `StatusBar:SetTimerDuration(dur)`
- `Cooldown:SetCooldownFromDurationObject(dur)` / `:SetCooldownFromExpirationTime(t)`
- `issecretvalue(v)`, `canaccessvalue(v)`, `Frame:HasSecretValues()`, `:SetToDefaults()`

> ✅ **Meridian est 100% compatible** — aucune donnée de combat. Toute détection se fait hors-combat (événements de récolte).

---

## ⚙️ Format .toc (Midnight)

```toc
## Interface: 120001
## Title: MonAddon
## Version: 1.0.0
## SavedVariables: MonAddonDB

locales\enUS.lua
locales\frFR.lua
Core\MonAddon.lua
```

Tags utiles : `## SavedVariablesPerCharacter:`, `## OptionalDeps:`, `## RequiredDeps:`, `[AllowLoadGameType mainline]`

---

## 💻 Règles Lua WoW

```lua
-- ✅ Namespace local — jamais de globales inutiles
local addonName, ns = ...
local MyAddon = {}
ns.MyAddon = MyAddon

-- ✅ Cache des globales fréquentes en haut de fichier
local pairs, ipairs, math_floor, string_format = pairs, ipairs, math.floor, string.format

-- ✅ Vider une table existante (pas de nouvelle allocation)
wipe(myTable)

-- ✅ Pools de frames pour contenu dynamique
local pool = CreateFramePool("Frame", parent)
local f = pool:Acquire()  --  ...  pool:Release(f)

-- ✅ Throttle obligatoire sur OnUpdate
local INTERVAL, elapsed = 0.1, 0
frame:SetScript("OnUpdate", function(self, dt)
    elapsed = elapsed + dt
    if elapsed < INTERVAL then return end
    elapsed = 0
    -- update
end)

-- ✅ Événements — pattern standard sans Ace
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event, ...) MyAddon[event](MyAddon, ...) end)
function MyAddon:PLAYER_LOGIN() ... end
```

---

## 🎨 Design Language Meridian : Glimmer Glass

> **Règle absolue :** Tout nouveau composant UI de Meridian respecte ce design language sans exception. Pas de `BackdropTemplate`, pas de fond coloré, pas de chrome WoW — uniquement le verre.

### Philosophie

Meridian adopte le design language **Glimmer** de Google, conçu à l'origine pour les lunettes AR. Principe central : l'interface est **du verre posé sur le monde**. Le joueur voit le jeu à travers l'UI. Aucun fond opaque, aucune couleur vive — seuls la transparence, une légère obscurité et de fins reflets signalent la présence de l'interface.

### Surface de verre — Fond

```lua
-- ✅ Fond Glimmer correct : noir quasi-transparent (valeur canonique Meridian)
local bg = frame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(frame)
bg:SetColorTexture(0.02, 0.02, 0.03, 0.68)

-- ❌ Interdit : fond coloré, gradient de couleur, BackdropTemplate WoW
frame:SetBackdrop({ bgFile = "..." })    -- JAMAIS
bg:SetColorTexture(0.1, 0.0, 0.2, 0.9)  -- JAMAIS (trop couleur/opaque)
```

### Bordures

4 textures séparées de 1px — jamais `BackdropTemplate` :

```lua
local function AddGlimmerBorder(frame)
    local function Edge(a1, a2, w, h)
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetColorTexture(1, 1, 1, 0.10)   -- blanc 10% alpha
        t:SetPoint(a1, frame, a1)
        t:SetPoint(a2, frame, a2)
        if w then t:SetWidth(w) else t:SetHeight(h) end
    end
    Edge("TOPLEFT",    "TOPRIGHT",    nil, 1)  -- haut
    Edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)  -- bas
    Edge("TOPLEFT",    "BOTTOMLEFT",  1,   nil) -- gauche
    Edge("TOPRIGHT",   "BOTTOMRIGHT", 1,   nil) -- droite
end
```

### Barres de ressources (Glow-trail)

Les barres utilisent un dégradé horizontal "glow-trail" — jamais une couleur unie :

```lua
-- Palette Glimmer (8 couleurs désaturées, cycliques par colorIndex)
local GLIMMER_COLORS = {
    { r=0.56, g=0.85, b=0.72 },  -- mint
    { r=0.95, g=0.78, b=0.45 },  -- ambre
    { r=0.50, g=0.75, b=0.95 },  -- ciel
    { r=0.90, g=0.58, b=0.62 },  -- rose
    { r=0.72, g=0.62, b=0.90 },  -- lavande
    { r=0.48, g=0.82, b=0.80 },  -- teal
    { r=0.95, g=0.82, b=0.48 },  -- or
    { r=0.90, g=0.70, b=0.72 },  -- rose poudré
}

-- Application du gradient : transparent à gauche → lumineux à droite
local c = GLIMMER_COLORS[colorIndex]
barTex:SetGradient("HORIZONTAL",
    CreateColor(c.r, c.g, c.b, 0.15),   -- début : quasi-transparent
    CreateColor(c.r, c.g, c.b, 0.75)    -- fin : lumineux
)
```

### Onglets

| État    | Fond                                        | Ligne de soulignement            |
| ------- | ------------------------------------------- | -------------------------------- |
| Actif   | Gradient couleur ressource `0 → 0.25 alpha` | 2px, même couleur à `0.85` alpha |
| Inactif | `SetColorTexture(0, 0, 0, 0)` (transparent) | Aucune                           |

### Bouton de fermeture

Ne jamais utiliser `UIPanelCloseButton`. Créer un `×` texte custom :

```lua
local closeBtn = CreateFrame("Button", nil, frame)
closeBtn:SetSize(20, 20)
closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
local closeTxt = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
closeTxt:SetAllPoints(closeBtn)
closeTxt:SetText("×")
closeTxt:SetTextColor(1, 1, 1, 0.45)
closeBtn:SetScript("OnEnter", function() closeTxt:SetTextColor(1, 1, 1, 0.90) end)
closeBtn:SetScript("OnLeave", function() closeTxt:SetTextColor(1, 1, 1, 0.45) end)
closeBtn:SetScript("OnClick", function() frame:Hide() end)
```

### Icône Minimap

```lua
bg:SetColorTexture(0.02, 0.02, 0.03, 0.85)  -- fond circulaire sombre
ring:SetColorTexture(1, 1, 1, 0.35)          -- anneau de bordure discret
highlight:SetColorTexture(1, 1, 1, 0.60)     -- highlight au survol
highlight:SetBlendMode("ADD")                 -- blend mode lumineux
```

### Récapitulatif des valeurs canoniques

| Élément              | Paramètre                                 |
| -------------------- | ----------------------------------------- |
| Surface (verre)      | `SetColorTexture(0.02, 0.02, 0.03, 0.68)` |
| Bordures 1px         | Blanc, alpha `0.10`                       |
| Barre début          | Couleur ressource, alpha `0.15`           |
| Barre fin            | Couleur ressource, alpha `0.75`           |
| Onglet actif (fond)  | Couleur ressource, `0 → 0.25` alpha       |
| Onglet actif (ligne) | Couleur ressource, alpha `0.85`           |
| Bouton `×`           | Blanc `0.45` → `0.90` au survol           |
| Fond minimap         | `0.02, 0.02, 0.03`, alpha `0.85`          |
| Anneau minimap       | Blanc, alpha `0.35`                       |

---

> **Debug in-game :** `/reload` • `/run <code>` • `/dump <expr>` • `/eventtrace` • `/fstack`

---

## 🔌 Dépendances Tierces — Auctionator (Phase 2)

Auctionator expose une API publique stable pour lire les prix stockés localement après un scan HV :

```lua
-- Toujours vérifier la présence avant appel (dépendance optionnelle)
local price = Auctionator and Auctionator.API and Auctionator.API.v1
    and Auctionator.API.v1.GetAuctionPriceByItemID("Meridian", itemID) or nil
-- Retourne le prix en cuivre (integer), nil si item inconnu ou Auctionator absent
-- Disponible n'importe quand — Auctionator stocke localement après chaque scan HV
```

Déclarer dans le `.toc` :

```toc
## OptionalDeps: Auctionator
```

---

_Pour toute API non couverte ici, consulter le wiki avant d'implémenter._
