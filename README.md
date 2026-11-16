# Fel Janitor

![WoW 3.3.5a (WotLK)](https://img.shields.io/badge/WoW-3.3.5a%20WotLK-a335ee?style=flat-square)
![Version](https://img.shields.io/badge/version-1.0.0-9482c9?style=flat-square)

Soul Shards that clean up after themselves.

**Fel Janitor** is a tiny World of Warcraft (WotLK 3.3.5) addon for warlocks. Whenever you are out of combat it deletes Soul Shards until only your chosen minimum is left — **10** by default. Nothing is ever deleted in combat.

## Features

- 🧹 **Automatic** — runs when combat ends, when your bags change, and on login / zone-in
- ⚔️ **Out of combat only** — shards you collect mid-fight stay until the fight is over
- 👜 **Soul bag aware** — shards in regular bags are deleted first, so the ones you keep are the ones in your soul bag
- ✋ **Hands off the cursor** — if you are holding an item, it waits
- 🟣 **Warlocks only** — on any other class it loads, says so and sits idle

## Installation

Put `FelJanitor.toc` and `FelJanitor.lua` in `Interface/AddOns/FelJanitor`, then enable **Fel Janitor** on the character selection screen (or `/reload`).

## Usage

| Command | Description |
| --- | --- |
| `/fj on` / `off` / `toggle` | Enable or disable cleanup |
| `/fj min <n>` | Number of Soul Shards to keep (default 10; `0` deletes all) |
| `/fj verbose` | Toggle a chat line each time shards are deleted |
| `/fj status` | Show whether it is on, the minimum, and how many shards you carry |
| `/fj` | Status plus the command list |

`/feljanitor` is the long-form alias. Settings are saved per character in `FelJanitorDB`.
