# Rensei Controls (for testers)

Checked against the game's input code on 2026-10-27: ClientHandler, Keybinds, Settings, UIHandler, HUDUI, CombatModeUI, JumpManager, SwimClient, DialogueUI, EmoteWheelUI and MobileControls (and GunAimUI, after the gun rework; TakedownUI and CombatModeUI's E-prompt rule, after the assassinations; HostageUI, TakedownUI's player prompt and EmoteWheelUI's menu, after hostages, 2026-10-29). Keys marked **(rebindable)** can be changed in Menu (P) > Keybinds.

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
| E | Combat Mode on or off (draw or sheathe). Out of combat, E also uses prompts (talk, inspect, doors). Only a prompt on E stops E from drawing (the takedown prompt, on N or its rebound key, doesn't; not live yet). |
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
| V | Carry a knocked target, or a takedown's or a grip's dead body (assassinations, not live yet) |
| B | Grip (finisher on a knocked target; never a dead body) |

Crouching blocks V and B: stand up first. So does a takedown in progress (assassinations, not live yet).

**Knocked yourself (2026-10-27, not live yet):** a knocked player can **crawl slowly** with the normal movement keys (WASD / the thumbstick) at 3 studs/s (PROPOSAL), playing Downed Crawl, and lies in Downed Idle when still. Nothing else works while you're down: no jump, attack, skill, alchemy, sprint, dash, crouch, climb or swim, and no grip or carry of your own. Being gripped or carried stops the crawl at once, and so does deep water (you float still). Knocked enemies and townsfolk don't crawl.

## Takedowns (PvE only)
Assassinations (2026-10-27, not live yet; the key and numbers are PROPOSAL). Only out of Combat Mode, from behind an enemy that hasn't caught you (unaware, suspicious or cautious, never alert). A prompt over the enemy shows its name and state. Crouching isn't required.

| Key | Action |
|---|---|
| N **(rebindable)** (tap) | Knock out an enemy from behind (it hasn't caught you; you're in Calm) |
| N **(rebindable)** (hold 0.6 s) | Assassinate it. Elites and Hunters: a backstab instead. Bosses can't be taken down |

N (rebindable): change it in Menu (P) > Keybinds > Takedown (2026-10-28, not live yet); the prompt shows the key you chose, at once. Tap and hold work the same on any key. A key left unbound (Unknown) shows no takedown prompt on keyboard and mouse; touch and gamepad still get it. B, V and H (the emote wheel) stay reserved. Players and townsfolk can never be taken down. Gamepad: the prompt's default button (ButtonX). Touch: tap or hold the prompt itself.

## Hostages (players only)
Hostages (2026-10-29, **not live**: built and tested, but switched off until the owner turns them on; every number is PROPOSAL). The same key as takedowns: **an enemy in reach is a takedown, a player is a hostage**, and when both are in reach the enemy wins. Never on a new player (under level 5) or anyone 15 or more levels below you, never in a station or other safe place, and never on an NPC.

| Key | Action |
|---|---|
| N **(rebindable, the takedown key)** | Take a knocked player hostage (1.5 s bind), or grab one from behind who hasn't seen you (an enemy in reach is a takedown instead). Works in or out of Combat Mode |
| N (holding) | The captor menu, on the emote wheel's circle: **Let them go**, **Finish them**, **Demand ransom** (then pick the amount), **Turn them in** (only at a State desk, with a Wanted hostage). N again, Esc or a right click closes it |
| Block key (F, rebindable) | Held: struggle (press it fast; the Struggle bar fills, slower against a stronger captor, 4 stamina a press) |

- **Holding someone:** you walk at 12 with no jump, sprint or dash, and only light attacks. No heavy, block, uppercut, weapon or class skill, gun, alchemy, emote, style change, item, climb or swim. No road crossing or train boarding with a hostage.
- **Held:** you can't move, jump, fight, cast, sprint, climb or use items, and your drawn tool is put away. Your camera stays free. The bar at the top shows how long the hold has left (180 s, less if you've been taken recently).
- **Gamepad:** the prompt's default button (ButtonX) takes a hostage and, while holding, opens the captor menu (tested with the key code only, not a real gamepad).
- Right after a fight (`InCombat`) the "Take hostage" prompt waits, like every prompt, until the combat tag clears. Combat Mode itself doesn't hide it.

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
| Takedown: tap or hold the prompt over the enemy (tap: knock out; hold: assassinate) | N (rebindable) |
| Hostage: tap the prompt over the player (Take hostage / Grab); **HOSTAGE** (the captor menu, while holding); **STRUGGLE** (while held, in Block's place) (not live) | N (rebindable); N (holding); F (held) |
| Bag, Stats, Menu, Mastery, Journal | `, M, P, K, J |

On a wall, the thumbstick moves you the same way W A S D does.

On touch screens, shots near an enemy lean onto them.

On touch screens, V shows only in Combat Mode, so carrying a knocked enemy or a body needs Combat Mode there (assassinations: no Calm carry button yet).

## Testers only
| Key | Action |
|---|---|
| F2 | Admin panel (admins only) |
