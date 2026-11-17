# Fel Janitor

![WoW 3.3.5a (WotLK)](https://img.shields.io/badge/WoW-3.3.5a%20WotLK-a335ee?style=flat-square)
![Version](https://img.shields.io/badge/version-1.2.1-9482c9?style=flat-square)

Soul Shards that clean up after themselves.

**Fel Janitor** is a tiny World of Warcraft (WotLK 3.3.5) addon for warlocks. Whenever you are idle it deletes Soul Shards until only your chosen minimum is left — **10** by default. Nothing is ever deleted in combat.

## Features

- 🧹 **Automatic** — runs when combat ends, when your bags change, and on login / zone-in, once you have been idle for a few seconds (5 by default, `/fj delay`)
- ⚔️ **Only when idle** — nothing happens while dead, in combat, while looting or casting, or while a vendor, bank, guild bank, mail, trade or auction window is open; shards you collect mid-fight stay until the fight is over
- 👜 **Soul bag aware** — loose shards are moved into free soul bag slots; shards in a soul bag count toward your minimum but are never deleted, only the overflow in regular bags is
- ✋ **Hands off the cursor** — if you are holding an item, it waits
- 🟣 **Warlocks only** — on any other class it loads, says so and sits idle

## Installation

Put `FelJanitor.toc` and `FelJanitor.lua` in `Interface/AddOns/FelJanitor`, then enable **Fel Janitor** on the character selection screen (or `/reload`).

## Usage

| Command | Description |
| --- | --- |
| `/fj on` / `off` / `toggle` | Enable or disable cleanup |
| `/fj min <n>` | Number of Soul Shards to keep (default 10; `0` deletes all) |
| `/fj delay <seconds>` | How long you must be idle before a cleanup, 1–60 (default 5) |
| `/fj verbose` | Toggle the chat line reporting each cleanup — shards moved or deleted (default on) |
| `/fj status` | Show whether it is on, the minimum, and how many shards you carry |
| `/fj` | Status plus the command list |

`/feljanitor` is the long-form alias. Settings are saved per character in `FelJanitorDB`.
