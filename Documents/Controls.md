# Rensei Controls (for testers)

Checked against the game's input code on 2026-10-25: ClientHandler, Keybinds, Settings, UIHandler, HUDUI, CombatModeUI, JumpManager, SwimClient, DialogueUI, EmoteWheelUI and MobileControls (and GunAimUI, after the gun rework). Keys marked **(rebindable)** can be changed in Menu (P) > Keybinds.

## Moving
| Key | Action |
|---|---|
| W A S D | Move |
| Space | Jump. **Tap at a wall** to grab it and climb (W A S D on the wall). **Hold** to wall-run. **Tap at a ledge** just above jump height to pull up onto it. |
| S (on a wall or ledge) | Drop off |
| Left Shift | Run (Settings > Auto Sprint changes how it starts) |
| Left Ctrl | Crouch to sneak. While running: slide. In Combat Mode, Ctrl only works with LMB (see Uppercut). |
| Q **(rebindable)** | Dash (8 directions; camera-relative in shift lock) |
| Alt | Shift lock (camera lock) |

## Fighting
Attacks and blocking only work in **Combat Mode**.

| Key | Action |
|---|---|
| E | Combat Mode on or off (draw or sheathe). Out of combat, E also uses prompts (talk, inspect, doors). |
| Left Mouse | Light combo. Hold to keep swinging. In the air: aerial attack. While running: dash attack. |
| Ctrl + Left Mouse | Uppercut (launches into an air juggle) |
| Right Mouse | Feint (cancels a light attack's wind-up). With guns in shooting mode: **fire (hold to keep firing)**. |
| R | Heavy attack. Pressed mid-combo, it comes out as soon as the current swing ends. |
| F **(rebindable)** | Tap: parry. Hold: block. A fresh press can parry even while you're being hit. |
| G **(rebindable)** | Lock on to a target |
| T **(rebindable)** | Weapon skill |
| Y **(rebindable)** | Guns: shooting mode on or off; the camera moves over your shoulder while it's on. Right Mouse fires while it's on. |

## Alchemy (Combat Mode)
| Key | Action |
|---|---|
| Z | Primary move |
| X | Secondary move |
| C | Utility move |
| V | Ultimate. If a knocked-down target is close, V carries them instead. |

Press to clap and hold to keep the clap ready. Release to cast where the camera is aiming, or at your lock-on target.

## Downed and knocked targets
| Key | Action |
|---|---|
| V | Carry a knocked target |
| B | Grip (finisher on a knocked target) |

**Knocked yourself (2026-10-27, not live yet):** a knocked player can **crawl slowly** with the normal movement keys (WASD / the thumbstick) at 3 studs/s (PROPOSAL), playing Downed Crawl, and lies in Downed Idle when still. Nothing else works while you're down: no jump, attack, skill, alchemy, sprint, dash, crouch, climb or swim, and no grip or carry of your own. Being gripped or carried stops the crawl at once, and so does deep water (you float still). Knocked enemies and townsfolk don't crawl.

## Swimming
Swimming revamp (2026-10-27, not live yet; the keys and numbers are PROPOSAL):

| Key | Action |
|---|---|
| W A S D | Swim. At the surface you stay level (looking down doesn't pull you under); underwater you swim toward where the camera looks |
| Left Shift | Swim faster (stamina; underwater it also uses air faster) |
| Left Ctrl | At the surface: dive (where the water is at least 4.5 deep). Underwater, hold: sink |
| Space | Underwater, hold: rise. At the surface, facing a low ledge (up to 4.5 above the water, within 3): climb out; otherwise a small hop |

Touch: SPRINT (hold), RISE (hold; tap at a low ledge to climb out) and DIVE (tap at the surface to dive; hold underwater to sink). They show only while you're swimming.

## Menus and screen
Menus are closed while you're in combat.

| Key | Opens |
|---|---|
| ` (the key left of 1) | Bag (inventory) |
| M | Stats |
| K | Mastery (skill tree) |
| J | Journal (quests, notes, Case Board) |
| P | Menu and Settings (including Keybinds) |
| Tab | Player list (leaderboard) |
| 1 to 0 | Hotbar slots |
| H (hold) | Emote wheel. Point and click to pick an emote. |
| Esc | Close a menu or a conversation |
| 1 to 9 (in a conversation) | Pick a dialogue choice |

## Touch screens (phones and tablets)
Every button does the same thing as its key. The fight buttons appear only in Combat Mode.

| Button | Key it matches |
|---|---|
| Attack (hold to keep swinging) | Left Mouse |
| Upper | Ctrl + Left Mouse |
| Heavy | R |
| Feint | Right Mouse |
| Block (hold; tap to parry) | F |
| Dash | Q |
| Jump (hold to wall-run; tap at a wall to climb) | Space |
| Fight / Calm | E |
| Run (toggle) | Shift |
| Slide (out of combat) | Ctrl |
| Skill (with a weapon) | T |
| Aim / Stop (with a gun, in Combat Mode) | Y |
| Fire (hold to keep firing; shows while shooting) | Right Mouse |
| Z, X, C (hold to keep the clap) | Z, X, C |
| V (Carry, otherwise Ultimate) | V |
| Grip (near a knocked body) | B |
| Bag, Stats, Menu, Mastery, Journal | `, M, P, K, J |

On a wall, the thumbstick moves you the same way W A S D does.

On touch screens, shots near an enemy lean onto them.

## Testers only
| Key | Action |
|---|---|
| F2 | Admin panel (admins only) |
