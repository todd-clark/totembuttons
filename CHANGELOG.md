# Changelog

## 0.1.55

- Duplicate totem buttons share buff checks and only repaint the tint when it changes.
- Keep buttons and their bindings attached during action-bar refreshes when the slot stays the same, reducing opportunities for the underlying macro icon to flash.

## 0.1.54

- Restore the Shaman spell buttons and the Imbues and Shields and Fire Nova sections in settings.

## 0.1.53

- Make missing-buff tint the main totem option. Enable Include non-buff totems to also tint totems based on distance outside instances.

## 0.1.52

- Track Mana Spring, Healing Stream, Mana Tide, and Grounding through their player buffs. For aura-tracked totems, the red tint reflects buff status even inside dungeons.

## 0.1.51

- Track persistent totem buffs by spell ID at every rank, including resistance totems, Strength of Earth, Windfury, Grace of Air, and Windwall.

## 0.1.50

- Check the actual buff spell IDs for all ranks of Flametongue Totem and Stoneskin Totem.

## 0.1.49

- Remove the extra five-second delay before highlighting a missing totem buff.

## 0.1.48

- Check whether supported totem buffs are active on you, including in dungeons where WoW hides position data.

## 0.1.47

- Show the selected spell in Totem Buttons tooltips when the underlying action bar also handles mouseover.

## 0.1.46

- Hide the underlying question-mark macro icon on default Blizzard and Bartender action bars, as well as EllesmereUI bars.

## 0.1.45

- Added the Totem Buttons logo to the WoW AddOns list and settings panel.
- Tightened the Shaman settings layout so Fire Nova fits inside the settings pane without a scrollbar.
- Let hovering over a Totem Buttons icon count as hovering over its underlying Ellesmere action button.
