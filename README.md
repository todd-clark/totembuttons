# Totem Buttons Forever

Totem Buttons adds class-specific buttons to your existing action bars in World of Warcraft Forever. Hover over a button to choose a spell, then click the button or use the slot's keybind to cast.

- **Shaman:** Add buttons for fire, earth, water, and air totems, weapon imbues, shields, or Fire Nova. See totem timers and range indicators where available. Right-click a totem button to dismiss its active totem. Fire Nova grays out when the addon can't confirm an active fire totem.
- **Paladin:** Add an aura button to choose among the auras you've learned. The button shows whether your selected aura is active.

## Installation

Copy the [`TotemButtons`](TotemButtons/) folder into your WoW Forever client's `_forever_/Interface/AddOns/` directory. Launch or restart the game and enable **Totem Buttons** in the AddOns list. EllesmereUI action bars and Bartender4 are optional.

## Setup

1. Log in on a Shaman or Paladin and type `/totembuttons` outside combat.
2. Drag an icon from the settings panel onto an action-bar slot.
3. Hover over the slot to select a spell. Click the button or press the slot's keybind to cast.

## Versioning

Increment the last number in `TotemButtons.toc` with each addon update, for example from `0.1.0` to `0.1.1`. The options screen reads the version from the loaded addon's metadata. Version `1.0.0` is reserved for the first stable release.
