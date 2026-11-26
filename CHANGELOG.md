# Changelog

## 0.2.23

- Draw Judgement's cooldown sweep above its colored aura artwork on action bars and the gamepad crossbar.

## 0.2.22

- Use Blizzard's aura display to restore Judgement's color when a seal is applied in combat.

## 0.2.21

- Gray out Judgement without an active seal when the Paladin gray-out option is enabled, and describe it in the option tooltip.

## 0.2.20

- Restore normal button icons on combat entry and refresh the gathering reminder when combat ends.

## 0.2.19

- Show gathering tracking on action buttons out of combat when tracking is off. Enable the option by default.

## 0.2.18

- Add a per-character gathering tracking reminder setting, off by default.

## 0.2.17

- Limit the gathering tracking reminder to Find Herbs and Find Minerals.

## 0.2.16

- Show a center-screen reminder when a known herb, mineral, or fish tracker is available and gathering tracking is off.

## 0.2.15

- Let the Judgement button apply the chosen seal out of combat while a different seal is still active.

## 0.2.14

- Retain the seal chosen from the Judgement flyout in combat and refresh the button when combat ends.

## 0.2.13

- Clarify the two-press Judgement sequence and label the Seals flyout's cast-on-selection setting.

## 0.2.12

- Restore separate presses for applying a Paladin seal and casting Judgement.

## 0.2.11

- Cast the selected Paladin seal and Judgement on the same press when starting out of combat with no active seal.

## 0.2.10

- Fix the Paladin Judgement button so selecting a seal updates its icon and cast action out of combat.

## 0.2.09

- Reduce the inward and outward reach of the Stormstrike lightning zigzag by 25%.


## 0.2.08

- Halve the number of Stormstrike lightning zigzags and restore their original depth.


## 0.2.07

- Halve the depth of the Stormstrike lightning zigzag.


## 0.2.06

- Show the low-mana tint while Lightning Shield is active, including when its native aura artwork is restricted.

## 0.2.05

- Double the length of the Stormstrike lightning bolt.


## 0.2.04

- Draw the Stormstrike lightning above slot artwork and extend its inward zigzag.


## 0.2.03

- Double the Stormstrike lightning thickness and let the bolt cross the slot edge as it circles.


## 0.2.02

- Loop the Stormstrike reset lightning for as long as the indicator is active.


## 0.2.01

- Release the current controller, flyout, and cooldown updates as 0.2.01.


## 0.1.102

- Refresh the shared GCD sample only on cooldown events and skip redundant crossbar visibility writes.

## 0.1.101

- Read the GCD from WoW Forever's reference spell so the sweep receives an active cooldown.

## 0.1.100

- Show a separate global cooldown sweep on regular and native gamepad Totem Buttons without replacing their active-effect timers.

## 0.1.99

- Scale the in-range aura artwork to match the crossbar icon when a controller layer expands in combat, preventing red edges from showing through.

## 0.1.98

- Refresh the controller grid from one slot snapshot, detach stale artwork before repainting, and refresh position changes even when button size stays the same.

## 0.1.97

- Keep in-range totem artwork aligned with the native crossbar when controller layers move in combat.

## 0.1.96

- Stop polling Blizzard-owned aura children for visibility. Their native timers update independently.

## 0.1.95

- Skip native aura buttons when WoW marks them forbidden, preventing errors during timer tracking and aura artwork updates.

## 0.1.94

- Record the first blocked native gamepad interaction call and its Lua stack each session to diagnose the loot popup.

## 0.1.93

- Remove addon registration from Blizzard's crossbar focus callbacks to reduce taint during loot transitions. Refresh the Stormstrike glow through the queued artwork updates instead.

## 0.1.92

- Defer crossbar visual updates from Blizzard focus and layout callbacks, and guard unavailable slot state during UI transitions such as looting.

## 0.1.91

- Restore the controller Sentry Totem view toggle through a dedicated secure action.

## 0.1.90

- Restore the 0.1.88 casting path after the controller Sentry Totem change caused button failures.

## 0.1.89

- Tap an active Sentry Totem on the native controller crossbar to switch views out of combat.

## 0.1.88

- Show the Stormstrike reset indicator on native gamepad crossbar buttons, including after changing layers during a reset.

## 0.1.87

- Show the Magma Totem icon when holding Fire Nova on the controller crossbar has reached the cast threshold.

## 0.1.86

- Hold and release the Fire Nova slot on the native gamepad crossbar to drop Magma Totem. A tap still casts Fire Nova.

## 0.1.85

- Reuse existing macros when placing buttons in Gamepad UI. Each crossbar slot keeps its own spell selection.

## 0.1.84

- Keep the controller totem sweep above the in-range aura art and hide the macro label while Totem Buttons owns the slot.

## 0.1.83

- Use the regular button timer, range tint, and active spell artwork on the native controller crossbar.

## 0.1.82

- Position controller flyouts above the crossbar slot captured at button-down, with a visible fallback if its coordinates are unavailable.

## 0.1.81

- Restore the visible flyout fallback for hidden or unavailable slot anchors.

## 0.1.80

- Anchor flyouts above the slot that opened them, including across controller layer visibility changes.

## 0.1.79

- Shorten the controller hold required to open a flyout.


## 0.1.78

- Open controller flyouts as soon as the hold is recognized, while the slot button is still down.

## 0.1.77

- Keep controller press and release on the native crossbar binding to avoid dropping quick taps when the key is rebound mid-press.

## 0.1.76

- Detect native gamepad UI mode and fit Totem Buttons icons to Blizzard's crossbar icon masks.

## 0.1.75

- Listen for both edges on bindable controller slots and restart hold tracking on a new press after a missed release.

## 0.1.74

- Restore the previous controller initialization and input handling after the hold timer caused macro icons to appear as question marks.

## 0.1.73

- Measure controller holds with a timed secure frame so quick taps cast and only hold-and-release opens the flyout.

## 0.1.72

- Add an Appearance checkbox to toggle the Stormstrike reset indicator. It is enabled by default.

## 0.1.71

- Native WoW Forever controller crossbar support. Tap the slot button to cast, or hold and release it to open the flyout. On Xbox-style controls, use D-pad Up/Down to browse, A to select, and B to cancel.
- Flyouts share mouse hover and wheel navigation across mouse, keyboard, and controller. Release the modifier to confirm a changed selection.
- Use the selected Modifier key with Fire Nova to drop Magma Totem. Active Sentry Totem switches views with left-click or its keybind out of combat. Right-click dismisses it.
- Consolidate settings into a single panel and update the flyout and Stormstrike highlights with a softer glow.


## 0.1.70

- Share wheel and mouse selection across flyouts and confirm hover selections when the modifier is released.

## 0.1.69

- Remove the Flyouts heading and label the dropdown Modifier key.


## 0.1.68

- Use the selected flyout modifier with Fire Nova to drop Magma Totem.
- Consolidate settings into one panel with no scrolling and shorter shortcut tips.
- Soften the rounded inner and outer glow for Stormstrike and flyout choices. Mouse-opened flyouts highlight the current choice and move the glow as you hover.


## 0.1.67

- Out of combat, left-click an active Sentry Totem or press its keybind to switch views. Right-click dismisses it.


## 0.1.66

- Add keyboard flyouts with a configurable Shift, Ctrl, or Alt modifier. Hold the modifier, open the flyout with the slot bind, scroll to a spell, and release the modifier to select it.
- Support the native Forever controller crossbar. Tap and release to cast, or hold and release to open the flyout for the slot you pressed.
- Add a Paladin Judgement slot with a seal picker for use out of combat when you have no seal active.
- Honor WoW mouseover casting for eligible spells on Totem Buttons slots.
- Show a blue-white lightning highlight on early Stormstrike resets when the client exposes an applicable signal.
- Reduce idle aura and totem polling and avoid full refreshes for unrelated action-slot changes.

## 0.1.65

- Show the Magma Totem shortcuts beside Fire Nova in the options menu.

## 0.1.64

- Ctrl plus a Fire Nova binding drops Magma Totem while the Fire Nova button is active.

## 0.1.63

- Ctrl-left-click Fire Nova to drop the highest learned rank of Magma Totem.

## 0.1.62

- Flash Stormstrike action buttons gold when the game signals a proc or a readable Stormstrike cooldown ends early.

## 0.1.61

- Draw the totem duration sweep and countdown numbers above the buff icon overlay.

## 0.1.60

- Let Blizzard display normal totem artwork over the red tint while the matching buff is active.

## 0.1.59

- Keep active totem tracking and artwork independent of the buff tint setup.

## 0.1.58

- Check totem buffs through Blizzard’s aura filter by default in and out of combat.

## 0.1.57

- Use Blizzard’s aura filter to update the missing-buff tint when direct buff lookups are restricted in dungeon combat.

## 0.1.56

- Tint action buttons Blizzard blue when you lack mana for the selected spell. The red range or missing-buff tint takes priority for an active totem.

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
