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
3. Restart or reload UI (`/reload`)

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
