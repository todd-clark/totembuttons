# Totem Buttons Forever

Totem Buttons adds class-specific buttons to your existing action bars in World of Warcraft Forever. Hover over a button to choose a spell, then click the button or use the slot's keybind to cast.

- **Shaman:** Add buttons for fire, earth, water, and air totems, weapon imbues, shields, or Fire Nova. See totem timers and range indicators where available. Right-click a totem button to dismiss its active totem. Out of combat, left-click or use the slot keybind to switch views when Sentry Totem is active. Fire Nova grays out when the addon can't confirm an active fire totem. Hold the selected keyboard flyout modifier while clicking Fire Nova or pressing its keybind to drop Magma Totem.
- **Paladin:** Add separate aura, seal, and buff buttons. Auras and seals can cast on selection or save the choice for the slot's usual keybind. The buttons show whether the selected effect is active on you, with countdowns for timed seals and buffs.

## Installation

Extract the release ZIP and copy its `TotemButtons` folder into your WoW Forever client's `_forever_/Interface/AddOns/` directory. Launch or restart the game and enable **Totem Buttons** in the AddOns list. EllesmereUI action bars and Bartender4 are optional.

## Setup

1. Log in on a Shaman or Paladin and type `/totembuttons` outside combat.
2. Drag an icon from the settings panel onto an action-bar slot.
3. Hover over the slot to select a spell. Click the button or press the slot's keybind to cast.

- **Keyboard** — Hold the configured flyout modifier (Shift by default), press the slot bind, and scroll to highlight a spell. Release the modifier to select it. The next normal keypress casts it. Existing keybinds keep priority. **Require selected modifier for hover flyouts** uses that same modifier.
- **Controller** — On a native Forever crossbar slot, tap and release to cast or hold to open the flyout. Use D-pad Up/Down to browse, A to select, and B to close it.
- **Judgement** — Pick a seal from its flyout. The slot offers that seal out of combat when no seal is active, and uses Judgement in combat or when a seal is active.
- **Mouseover cast** — Eligible spells follow WoW’s Mouseover Cast setting and modifier.
- **Stormstrike** — The action slot can flash blue-white when the addon detects an early reset. Type `/totembuttons stormstrike` to test the glow and see the available reset signals.

## Verification

Run `lua5.1 tests/check.lua` from the repository root. It checks the addon load list, Lua syntax (including secure snippets), and regressions in shortcut routing, saved settings, and flyout selection. GitHub Actions runs the same check before packaging.

In WoW Forever, check the following after changing secure input or aura handling:

- Open a keyboard flyout with the cursor locked, scroll, and release the modifier. Confirm that the next press casts the selected spell and that opening without scrolling preserves the selection.
- From a held controller layer, tap to cast and long-press to open the flyout. Release the layer button before and after the slot button in separate attempts. Confirm D-pad navigation, A selection, and B cancellation while in combat.
- Check a native aura overlay while fading its host bar, then hide and reveal the bar with a live aura.
- Pick a different totem in combat, check Ctrl + Fire Nova still casts Magma Totem, and trigger an early Stormstrike reset at 2/2 Improved Stormstrike.
- Check Judgement before and after sealing, during combat, and between dungeon pulls.

## Highlight texture

The flyout and Stormstrike share `HighlightBorder.tga`. It contains a rounded stroke and a glow that fades inward and outward.
The addon tints both masks per spell or effect.
Reuse the same texture for additional classes and supply the color in Lua.
Run `python3 scripts/generate_highlight_border.py` to regenerate it after
changing the shared shape. GitHub Actions checks that the saved texture
matches the generator.

## Versioning

Increment the last number in `TotemButtons.toc` with each addon update, for example from `0.1.0` to `0.1.1`. The options screen reads the version from the loaded addon's metadata. Version `1.0.0` is reserved for the first stable release.

Add a matching `## 0.1.1` section to [CHANGELOG.md](CHANGELOG.md) with the player-facing changes. On a push to `main`, GitHub Actions includes all notes newer than the last successful CurseForge upload. A push with a version already submitted or superseded skips the upload.
