An Emberveil WoW addon that automatically dismounts and cancels shapeshifts when you interact with NPCs, merchants, or the taxi system. Designed to eliminate the "Can't speak while shapeshifted" error.

## Features

- 🧙 **Auto-cancel shapeshifts** – Ghost Wolf, Bear/Cat/Aquatic/Travel/Moonkin Form, Shadowform
- 🐴 **Auto-dismount** – cancels mount buffs when available
- 💬 **NPC target trigger** – cancels forms the moment you target a friendly NPC
- 🏪 **Merchant trigger** – cancels forms when a merchant window opens
- ✈️ **Taxi trigger** – cancels forms when the taxi map opens
- 🔄 **Form cache** – remembers your active form even when `UnitBuff` is empty (taxi map / merchant UI)
- 🎯 **Smart target handling** – restores your NPC target after the form is removed
- 🌍 **Emberveil (1.12.1) compatible**

## Installation

1. Download the `AutoDismount` folder
2. Place it in your World of Warcraft AddOns directory:
   - **Windows**: `\Interface\AddOns\`
   - **Mac**: `/Interface/AddOns/`
3. Restart WoW or reload UI (`/reload`)

## Usage

### Automatic Triggers

The addon runs automatically. No setup required. Three triggers:

| Trigger | What happens |
|---------|--------------|
| **Target a friendly NPC** | Form is cancelled immediately, target is restored |
| **Merchant window opens** | Form is cancelled |
| **Taxi map opens** | Form is cancelled |

This means you can just walk up to an NPC in Ghost Wolf, left-click them, and the form will drop — then right-click and interact normally.

### Commands

- `/ad` – Show help
- `/ad toggle` – Enable/disable the addon
- `/ad merchant` – Toggle trigger at merchants
- `/ad taxi` – Toggle trigger at taxi map
- `/ad npc` – Toggle trigger when targeting NPCs
- `/ad forms` – Toggle shapeshift cancellation
- `/ad debug` – Toggle debug messages
- `/ad test` – Trigger manually (use outside of forms)
- `/ad scan` – List all active buffs and cached form (debug)

## How It Works

### The Problem

In vanilla 1.12.1, when you're in a shapeshift form (Ghost Wolf, Bear, Cat, etc.) and right-click an NPC, the client shows **"Can't speak while shapeshifted"** and blocks the interaction. This is a client-side restriction and cannot be bypassed directly — the form must be removed first.

### The Solution

The addon hooks `PLAYER_TARGET_CHANGED`. The moment you left-click a friendly NPC, it:

1. Detects the current form (live scan or cached value)
2. Clears the target so the self-cast spell is not redirected to the NPC
3. Casts the form's toggle spell to remove it (`CastSpellByName("Ghost Wolf")`)
4. Restores your previous target after 50 ms

Result: the form drops instantly, the NPC stays targeted, and right-click works normally.

### The Form Cache

A common problem on private servers: `UnitBuff("player", i)` returns an empty list while a modal UI (taxi map, merchant window) is open. This means the addon cannot detect the form at the exact moment it needs to cancel it.

The form cache solves this:

- A background frame polls `UnitBuff` every **0.5 seconds**
- When a form is detected, its spell name is stored with a timestamp
- When a modal UI opens and `UnitBuff` goes empty, the addon falls back to the cached value
- The cache expires after **3 seconds** of inactivity (so leaving the form manually clears it)

### Why `CastSpellByName` Works

In Emberveil, `RunScript("CastSpellByName(...)")` and `pcall(CastSpellByName, ...)` behave differently:

| Method | Normal play | Modal UI (taxi/merchant) |
|--------|-------------|--------------------------|
| `RunScript("CastSpellByName(...)")` | ✅ Works | ❌ Blocked |
| `pcall(CastSpellByName, ...)` | ✅ Works | ✅ Works |

The addon tries the direct `pcall(CastSpellByName, ...)` first, and only falls back to `RunScript` if that fails.

### Why Target Must Be Cleared

If you cast a self-spell while a friendly NPC is targeted, the client tries to cast it **on the NPC** instead of yourself. The server rejects this and the form stays up. Clearing the target first forces the spell to target the player.

## Supported Forms

| Class | Form | Toggle Spell |
|-------|------|--------------|
| Shaman | Ghost Wolf | "Ghost Wolf" |
| Druid | Bear Form | "Bear Form" |
| Druid | Cat Form | "Cat Form" |
| Druid | Aquatic Form | "Aquatic Form" |
| Druid | Travel Form | "Travel Form" |
| Druid | Moonkin Form | "Moonkin Form" |
| Priest | Shadowform | "Shadowform" |

Forms are identified by their **texture icon name** (not the spell name), so the addon works regardless of your client language.

## API Compatibility Notes

Emberveil's Lua environment differs from vanilla in several ways. The addon handles these:

- `CancelShapeshiftForm()` – **not available** (`nil`), so form removal uses `CastSpellByName` toggle instead
- `SitStandOrDescendStart()` – **not available** (`nil`), so dismount uses `/sit` via `RunScript`
- `GetPlayerBuff()` – **not available**, so buff scanning uses `UnitBuff`
- `UnitBuff()` returns the texture path in the **name** field, and `nil` in the texture field – the addon handles both formats
- Texture paths use the format `/Game/Interface/Icons/Name_TEX` – the addon strips the `/Game/` prefix and `_TEX` suffix

## Saved Variables

The addon stores its settings in `WTF/Account/<account>/SavedVariables/AutoDismount.lua`:

```lua
AutoDismountDB = {
    enabled = true,
    onMerchant = true,
    onTaxi = true,
    onNpcTarget = true,
    cancelForms = true,
    debug = false,
}
