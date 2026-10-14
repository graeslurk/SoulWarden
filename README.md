# Soul Warden

Keeps a warlock's soul shards in check. Choose the most shards you want to
carry, then press a hotkey (or click a macro) to delete one spare shard at a
time until you're down to that many. Made for **WoW Forever**.

## How it works

- Set your **maximum soul shards** in the window (`/soulwarden`). The default is 10.
- Each press of the **hotkey** deletes one shard while you carry more than your maximum.
  Set the key in the game's Key Bindings, under **Soul Warden**.
- Prefer a button? `/soulwarden delete` in a macro does the same. The window's
  **Create macro** button makes one and puts it on your cursor.
- Shards are only deleted from your **normal bags**. Shards in a **soul bag**
  count towards your total but are never deleted.
- A chat message tells you each time a shard is deleted and how many are left.
  You can turn it off.
- A **minimap button** opens the window. A red badge on it shows how many
  shards you're over your limit, and its tooltip shows your shard count.
  Drag it to move it around the minimap (square minimaps work too), or turn
  it off in the window or with `/soulwarden minimap`.

One shard per press, by design: the game only lets addons delete an item when
you press a key or click.

## Commands

| Command | |
|---|---|
| `/soulwarden` | Open the window |
| `/soulwarden delete` | Delete one shard over your limit (for macros) |
| `/soulwarden max <number>` | Set the most soul shards to carry |
| `/soulwarden chat` | Turn the message for each deleted shard on or off |
| `/soulwarden minimap` | Show or hide the minimap button |

## License

All rights reserved, see `LICENSE`.
