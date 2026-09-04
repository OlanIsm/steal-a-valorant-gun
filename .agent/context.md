# Roblox Idle Game: "Gun Tycoon" - Full Game Architecture Prompt

You are building a Roblox idle/incremental game loop inspired by "Steal a Brainrot" and "Steal an Egg". 

## Core Game Loop

**Phase 1: Collection**
- Random guns spawn from a CENTER GENERATOR on the map (Valorant-style assets or Roblox gun models)
- Each gun type has:
  - Unique name (e.g., "Vandal", "Phantom", "Sheriff")
  - Money generation rate per second (e.g., $5-$100/sec)
  - ATK Damage value (e.g., 5-50 damage)
  - Rarity tier (Common, Rare, Epic, Legendary → affects stats)
- Player walks to generator, touches a gun, picks it up

**Phase 2: Base Building**
- Player has a personal BASE with an 8-SQUARE GRID
- Each square is a PRODUCTION SLOT where guns can be placed
- When gun placed on square:
  - Gun AUTOMATICALLY generates money per second
  - Money flows into a COLLECTION POT (visual: coins/cash pile)
  - Player can tap/click the pot to COLLECT money
  - Gun sits there permanently until player removes/swaps it

**Phase 3: Income & Upgrades**
- Collected money goes to UPGRADE POOL
- Upgrades available:
  - **Gun Stats** → Increase ATK Damage (global multiplier, e.g., +10% damage per upgrade)
  - **Production Speed** → Increase money/sec generation (global multiplier, e.g., +5% production per upgrade)
  - **Luck/Rarity** → Better guns spawn from generator (5% chance per tier)
- Each upgrade costs exponentially more (e.g., first: $100, second: $250, third: $625, etc.)

**Phase 4: Combat (Optional, can be minimal)**
- Periodically, an ENEMY spawns on the map
- Enemy has health = sum of all gun ATK Damage placed on player's squares
- Player taps/clicks guns to deal damage (or auto-deal based on production ticks)
- Defeating enemy gives BONUS MONEY or RARE GUN DROP
- Enemy respawns after defeat

**Phase 5: Rebirth System**
- After reaching a MILESTONE (e.g., $1M total, 50 upgrades, or defeating 10 enemies):
  - Player can REBIRTH → reset money & guns, but keep:
    - A permanent MULTIPLIER (e.g., +10% production per rebirth)
    - A REBIRTH LEVEL (shows progression)
  - Reborn players spawn with a STARTING BONUS (e.g., 3 starter guns)
  - Incentive: Second loop is faster thanks to multipliers

## Technical Requirements

**Scripts Needed:**
1. **GunGenerator.server.lua** → Spawns random guns, handles gun pickup
2. **PlayerBase.server.lua** → Manages 8-square grid, production per gun
3. **MoneySystem.server.lua** → Tracks collected money, handles upgrades, rebirth
4. **UI/MoneyDisplay.client.lua** → Shows current money, production rate, upgrades
5. **UI/BaseGrid.client.lua** → Visual 8-square grid, place/swap guns
6. **Combat.server.lua** → Enemy spawn, player attack, damage calculation

**Keep Each Script Under 300 Lines** (modular, vibecoding-friendly)

**Use RemoteEvents for:**
- Gun pickup (client → server)
- Money collection (client → server)
- Upgrade purchase (client → server)
- Rebirth trigger (client → server)

**Use RemoteProperties for:**
- Real-time money count (update UI live)
- Production rate (update UI live)
- Rebirth multiplier (persistent across resets)

## Mechanics Details

**Gun Generation:**
- Random gun spawns every 3-5 seconds at center
- Each gun is a Part with a billboard GUI showing name + stats
- Gun sits there for 30 seconds before despawning
- Gun rarity = random (70% Common, 20% Rare, 8% Epic, 2% Legendary)

**Production:**
- Every 1 second, each placed gun generates: money = (base_money * production_multiplier)
- Money pools into a visual "collection pot" (Part + TextLabel showing total)
- Player clicks pot to claim money (feels like real progress)

**Upgrade Costs:**
Level 1: $100
Level 2: $250
Level 3: $625
Level N: $100 * (2.5 ^ (N-1))


**Rebirth Logic:**

RebirthMultiplier = 1.1 ^ RebirthLevel
All production rates = base_production * RebirthMultiplier
Guns reset, money resets, upgrades reset (but multiplier stays)

## UI/UX Flow

- **Top Left:** Current Money ($X,XXX), Production Rate ($/sec)
- **Top Right:** Rebirth Level, Total Rebirths
- **Center Screen:** 8-square base grid (visual representation)
- **Bottom Left:** Upgrades panel (Gun Damage, Production Speed, Luck)
- **Bottom Right:** Collection pot (click to collect money)

## Best Practices for Vibecoding This

1. **Start with gun spawning** → make sure guns appear, player can pick them up
2. **Add production loop** → money ticks, UI updates
3. **Add upgrade system** → test cost scaling, balance feels good
4. **Add combat** → enemy spawns, takes damage, dies (simple)
5. **Add rebirth** → optional last, tests persistence
6. **Iterate fast:** Each script change = instant feedback in Studio via Rojo

## Questions for You (Before Coding)

- Gun stats scale: Should legendary guns give 10x more money than common? Or 3x?
- Rebirth timing: When should rebirth be "worth it"? (e.g., after 10 mins of gameplay?)
- Combat difficulty: Should enemies scale with player upgrades?
- Art style: Use Roblox default assets or custom textures?

---

Now generate a complete, modular Lua script architecture for this game. Prioritize:
- Clear variable names
- Comments for each section
- Reusable functions (don't repeat code)
- Network optimization (minimize RemoteEvent firing)
- Start with GunGenerator.server.lua first

Keep each script under 300 lines. Break into smaller files if needed.

you can also look at roblox popular game for GUI reference