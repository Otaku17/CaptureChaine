<p align="center">
  <img src="https://cdn.discordapp.com/attachments/1015276970625466474/1499740699493404672/pwa-512.png?ex=69f5e5de&is=69f4945e&hm=7be959182dd4de4f0ce5a6db9b29bc2f9abb4caea7a342469fe6b9b7efb9c759&" width="300">
</p>

# CaptureChain

CaptureChain is a Pokemon SDK plugin that adds a capture combo system for wild Pokemon.
When the player repeatedly catches the same species, the chain grows and future encounters
of that species can receive better shiny odds and guaranteed perfect IVs.

The plugin is lightweight, automatic, and configurable through JSON.

---

## Features

- Tracks consecutive captures of the same species
- Applies bonuses only to the currently chained species
- Improves shiny odds based on chain length
- Grants a configurable number of guaranteed perfect IVs
- Can break the chain when the player flees
- Can break the chain after a failed battle against the chained species
- Supports standard wild encounters and forced wild battles
- Exposes a small script API for events and custom logic

---

## Installation

0. Download [Discord.psdkplug](https://github.com/Otaku17/CaptureChaine/releases)

1. Place the plugin in your project's `scripts` folder.

2. From the root of your project, load or reload plugins:

```bash
.\psdk --util=plugin load
```

3. Configure the generated file in:

```text
Data/configs/capturechain_config.json
```

---

## How It Works

The chain starts when the player catches a wild Pokemon.

- If the next captured Pokemon is the same species, the chain count increases
- If the next captured Pokemon is a different species, a new chain starts for that species
- Bonuses are applied only to new wild encounters of the currently chained species
- Already shiny Pokemon are left unchanged

Depending on your configuration, the chain can also be reset when:

- The player flees from a wild battle against the chained species
- The player finishes a wild battle against the chained species without catching it

The chain data is stored in the player's save data.

---

## Configuration

All plugin settings are defined in:

```text
Data/configs/capturechain_config.json
```

Default configuration:

```json
{
  "storage_key": "capture_chain",
  "stat_count": 6,
  "bonus_table": [
    {
      "min": 31,
      "shiny_rate": 341,
      "perfect_ivs": 4
    },
    {
      "min": 21,
      "shiny_rate": 512,
      "perfect_ivs": 3
    },
    {
      "min": 11,
      "shiny_rate": 768,
      "perfect_ivs": 2
    },
    {
      "min": 6,
      "shiny_rate": 1024,
      "perfect_ivs": 1
    },
    {
      "min": 1,
      "shiny_rate": 2048,
      "perfect_ivs": 0
    }
  ],
  "break_on_player_flee": true,
  "break_on_failed_battle_against_chained_species": true
}
```

---

## Configuration Fields

### `storage_key`

```json
"storage_key": "capture_chain"
```

Key used in save data to store the current chain state.

- Type: `String`
- Default: `"capture_chain"`

You usually do not need to change this unless you want a different save key.

### `stat_count`

```json
"stat_count": 6
```

Defines how many IV stats are considered when applying guaranteed perfect IVs.

- Type: `Integer`
- Default: `6`

For a standard Pokemon setup, keep this value at `6`.

### `bonus_table`

```json
"bonus_table": [
  {
    "min": 31,
    "shiny_rate": 341,
    "perfect_ivs": 4
  }
]
```

This table defines chain thresholds and their rewards.

- Type: `Array<Hash>`
- Ordered automatically by highest `min` first

Each entry supports:

| Field | Type | Description |
|-------|------|-------------|
| `min` | Integer | Minimum chain length required |
| `shiny_rate` | Integer | Shiny roll rate, using `rand(rate) == 0` |
| `perfect_ivs` | Integer | Number of guaranteed 31 IVs |

Example:

```json
{
  "min": 21,
  "shiny_rate": 512,
  "perfect_ivs": 3
}
```

This means:

- At chain count `21` or higher
- Encountered chained Pokemon have a `1 / 512` shiny roll
- They also gain `3` guaranteed perfect IVs

### `break_on_player_flee`

```json
"break_on_player_flee": true
```

If enabled, fleeing from a wild battle against the chained species resets the chain.

- Type: `Boolean`
- Default: `true`

### `break_on_failed_battle_against_chained_species`

```json
"break_on_failed_battle_against_chained_species": true
```

If enabled, ending a wild battle against the chained species without catching it resets the chain.

- Type: `Boolean`
- Default: `true`

---

## Bonus Logic

The plugin checks the current chain count and picks the first matching bonus entry.

With the default config:

- Chain `1+`: `1 / 2048` shiny rate, `0` perfect IVs
- Chain `6+`: `1 / 1024` shiny rate, `1` perfect IV
- Chain `11+`: `1 / 768` shiny rate, `2` perfect IVs
- Chain `21+`: `1 / 512` shiny rate, `3` perfect IVs
- Chain `31+`: `1 / 341` shiny rate, `4` perfect IVs

If no bonus matches, no special bonus is applied.

---

## What Resets the Chain

The chain resets when:

- You manually call `CaptureChain.reset!`
- The player flees from a wild battle against the chained species, if enabled
- A wild battle ends without capture against the chained species, if enabled

The chain does not reset just because you encounter another species.
It only changes when you successfully capture a new species and start a new chain.

---

## Script API

The plugin exposes methods directly on `CaptureChain` and helper methods on `Interpreter`.

### Core API

Get full chain status:

```ruby
CaptureChain.status
```

Returns a hash like:

```ruby
{
  species: :pikachu,
  count: 12,
  last_capture_map_id: 5
}
```

Get chained species:

```ruby
CaptureChain.species
```

Get current chain count:

```ruby
CaptureChain.count
```

Check if a chain is active:

```ruby
CaptureChain.active?
```

Get current bonus entry:

```ruby
CaptureChain.current_bonus
```

Example return value:

```ruby
{ min: 11, shiny_rate: 768, perfect_ivs: 2 }
```

Get only the shiny rate:

```ruby
CaptureChain.shiny_rate
```

Get only the number of perfect IVs:

```ruby
CaptureChain.perfect_ivs
```

Reset the current chain:

```ruby
CaptureChain.reset!
```

### Interpreter Helpers

These methods can be convenient in event script calls:

```ruby
capture_chain_status
capture_chain_count
capture_chain_species
capture_chain_bonus
capture_chain_shiny_rate
reset_capture_chain
```

---

## Technical Notes

- Wild encounter bonuses are applied when a Pokemon is generated
- Forced wild battle arrays are also processed
- The plugin only applies shiny bonuses to non-shiny generated Pokemon
- Perfect IVs are assigned only to stats below 31
- The bonus table is read from config at runtime

---

## File Overview

```text
scripts/CaptureChain/
├── config.yml
└── scripts/
    ├── 000 ConfigLoad.rb
    ├── 001 CaptureChainCore.rb
    ├── 002 CaptureChainWildPatch.rb
    ├── 003 CaptureChainCatchPatch.rb
    ├── 004 CaptureChainApi.rb
    └── 005 CaptureChainBattlePatch.rb
```

---

## Recommended Balancing Tips

- Keep early thresholds generous enough to make chaining feel rewarding
- Avoid making shiny rates too low too quickly unless your game is built around chaining
- Use `perfect_ivs` carefully if you want to preserve encounter rarity balance
- If you want a more forgiving system, disable one or both chain break options

---

## Compatibility

This plugin is designed for Pokemon SDK style projects using the plugin/config system.

If another plugin also rewrites wild encounter generation, catch flow, or battle end handling,
you should verify method alias order and behavior.

---

## Credits

Made with ❤️ for Pokémon SDK & Ruby projects.
