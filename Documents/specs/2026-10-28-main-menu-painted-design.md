# Main Menu: Painted Save-Slot Screen and Slot Pan (design)

**Date:** 2026-10-28. **Status:** approved by the owner (decisions below); art not yet approved, nothing uploaded, built or published. Prices and slot rules are Rensei's own (`Rensei.Slots`); every other number here is a **PROPOSAL**.

**The owner's request:** "can you hand paint a similar version of the loading screen based on the reference, make sure the background is animated, and when you click a character slot it pans to your character slot (if you haven't customized it or want to edit it)".

**The reference** (another game's menu) is used for layout and mood only: a dark textured background, a gold title top left, buttons on thin ornate frames, a grid of save-slot cards on the right, and a tip line bottom left. None of its art, text or title is copied.

**Owner decisions (2026-10-28):**
- The background is a **painted 3D diorama**: painted layers set at depths behind the menu stage, animated.
- **One alcove per slot:** each slot's character stands in its own alcove; clicking a slot pans the camera to it.
- **Edit is appearance only:** hair, face parts, hair colour and skin (Creator Plus rule kept). Name, clan, nation, gender and weapon stay locked.
- **A Studio-only TestNoSave guard in MenuData**, as in Ye's DataManager, so Main Menu Play tests can't write real saves.
- Art is painted and rendered locally first; the owner approves it before any image is uploaded.

**Owner direction during the concept (2026-10-28):**
- "Make it higher quality": the diorama is a lit 3D scene in Blender (`Art/MainMenu/menu_scene.py`: Eevee, volumetric smoke and light shafts, depth of field), painted over with the compositor's anisotropic Kuwahara filter. The 2D painter (`paint_menu.py`) now only draws the UI art and the mockup.
- "Make the textures higher quality": `menu_textures.py` paints them in layers at full size (4096² chalk circles; a woven, embroidered banner; a crazed enamel clock in a brass bezel; a chipped enamel station sign). The Blender materials carry pitted stone, grimy mortar, soot streaks, rusted iron and wet flagstones.
- "More FMA like Rensei's theme": the series' words and mood, Rensei's own lore and symbols (Lore Bible §1): chalk transmutation circles with a blue reaction, State Authority banners, State Alchemists, a station clock, the FOUNDRY YARD sign, dull-red Philosopher's Stones, an old Mezarath circle in the smoke, a clock tower and a domed Authority hall. The tip line uses true tips (Equivalent Exchange; Heat decays even offline; unlicensed casting is a crime).
- "Lower to compensate for roblox's UI overlap": the logo starts at y 168 and the buttons at y 420 (of 1080), clear of Roblox's top bar (about the top 60 px on the left).
- "Use a roblox rigged r6 model": the owner's R6 rig `E:/Blender Shit/CHARACTER SHIT/PaintRigV3.blend` (armature "RoBone", bendy six-part body, IK knees), loaded fresh per figure and posed through its bones. "Cool idle poses that don't overlap into the buildings": the alcoves are 1.7 m wide (an R6 is 4 units wide at the arms); slot 1 stands arms crossed with its weight on one leg, slot 2 at parade rest, the empty slot is the plain grey R6; a stone R6 statue claps (Rensei's alchemy clap) on a plinth.
- "Make the menu animated, with animated background, ambiance": an animated preview (`menu_anim.py`, `compose_anim.py`, `encode_video.py`) and a soundtrack synthesised from scratch (`menu_ambience.py`; a 60 s seamless loop for the game too). See §2 and §4 for what moves.

## 1. How the menu works today (read 2026-10-28)

- `MenuClient` builds the UI in code from the game's UI kit (Guru font). Title screen: the Rensei logo (`rbxassetid://130654945285755`), PLAY, CLAN INDEX. PLAY opens a separate slot screen: a row of rarity-framed cards, star and trash icons, a New Slot card at the live price.
- The scene is 3D: one preview rig on `Workspace.MenuStage.Dais`, camera at `MenuStage.CameraMark` (`CamFar`). The creator uses `CamFace` / `CamBody`, computed from the dais. One `RenderStepped` lerps the camera toward `CamTarget`.
- A created slot's click calls `Open` then `Play`. An empty slot's click calls `Open` then the creator. `Create` refuses a slot that already has a character, so editing is not possible today.
- Slots: 2 free, up to 5; a new slot is 200 R$ list price (`Slots.Price`; Managed Pricing showed 160). The profile stores no play time.
- **Save path:** the slot list reads each slot with `ViewProfileAsync`, which in this ProfileService version goes through `UpdateAsync` (a write). `Open` writes the account record (`SlotAccount.Select`) and session-locks the profile. So any Play test of the slot screen touches real saves.

## 2. The scene (painted diorama)

A rail-platform foundry hall at dusk, in Rensei's dark industrial-fantasy style:
- **Far layer:** a soot-black foundry town and a rail viaduct on a dim amber sky, smoke banks with a faint gold transmutation circle.
- **Mid layer:** iron gantries and the hall's arched trusses framing the view.
- **Near layer:** hanging chains and a lantern at the edges.
- **Alcoves (3D parts, not painted):** a back wall with five arched niches, one per possible slot, each with a lantern. A created slot's niche holds its character in its saved look. An owned empty slot shows a chalk circle and a covered mannequin. An unowned slot's niche stays dark.
- **Animation:** fog bands drifting (scrolling textures), embers and ash rising (ParticleEmitters with Roblox's built-in particle textures), slow light shafts (Beams), the sigil pulsing, a train lamp crossing the viaduct now and then, and a slow camera sway so the layers parallax.

## 3. The UI

- **Left:** the existing Rensei logo; PLAY and CLAN INDEX on a new painted thin frame. No CREDITS (Rensei has no credits screen).
- **Slot cards** (right, 2 columns): a new painted 9-slice frame (steel scrollwork, crescent end-caps, diamond studs, as in the Health and Posture frames), with the gold line-art corners for hover and the starred slot. A created card: a bust of that slot's character (ViewportFrame), name, "Lv N · Clan" in the rarity colour, nation, last region; star, trash and a new EDIT icon. An owned empty card: "CREATE CHARACTER". The New Slot card: the live price.
- **Tip line** (bottom left): "[WORD ON THE RAILS]" and a rotating tip that is true of the game.
- PLAY keeps opening the slot cards (the flow stays the same).

## 4. The pan

- An empty owned slot, or a created slot's EDIT icon: the UI fades, and the camera follows a curve (about 1.6 s, ease in-out) from the menu view to that slot's alcove. It lands on the creator's BODY view of that alcove, and the existing creator opens. FACE and BODY are computed from the alcove, not the dais. BACK to the slots pans back.
- A created slot's card click keeps today's behaviour: `Open` then `Play`, no pan.
- `MenuPan` (new client module) owns the camera curve; during a pan the existing lerp is paused.

## 5. Server changes

- **`MenuData.Summaries`:** each entry also carries the slot's cleaned `Appearance` and its last region (`Travel.Region`), read from data it already reads.
- **`MenuServer` `Edit`, Choice:** only for a created character in the open slot. It runs the same checks as `Create` (Customization.Clean, the Creator Plus skin rule, hair IDs loading) and writes only `Identity.Appearance` (body kept from the saved gender, outfit kept from the nation). The creator in edit mode hides the locked steps' controls.
- **TestNoSave in MenuData (Studio only):** with `ServerStorage:GetAttribute("TestNoSave") == true` and `RunService:IsStudio()`, slots are read with `GetAsync` into ProfileService mock profiles, the account record is kept in memory (no `UpdateAsync` from `Select`, `SetFavorite`, `Redeem`), and Delete wipes only the mock. The server warns once and sets `ReplicatedStorage`'s `TestNoSave`. Off, the code runs exactly as before.

## 6. Art (to be approved before upload)

Painted locally by `Art/MainMenu/paint_menu.py` (procedural brushwork in Python) into `E:/Rensei/Renders/MainMenu/`. About six images to upload, each only with the owner's OK: the three layers, the fog strip, the card frame and the button frame.

## 7. Testing

- Play tests only with TestNoSave on, proven on before anything is clicked.
- Checked: the backdrop animates; each slot's alcove shows the right character; the pan lands on the right alcove and the creator opens; BACK pans back; Edit saves appearance only (on the mock); a created slot's click still plays. Screens captured to `E:/Rensei/Work/main-menu/`.
