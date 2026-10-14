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

## Reporting bugs

Open an issue here on GitHub. Please include what you did and what happened,
the Soul Warden version (shown next to the title in the window, `/soulwarden`)
and any error message you got.

## About me

Hi, I'm Graeslurk! I play WoW Forever and make addons in my spare time. I also
made [Pocket Goblin](https://github.com/graeslurk/PocketGoblin).

Bug reports and ideas are very welcome: open an issue here on GitHub.

If Soul Warden saves you some bag space and you'd like to say thanks, you can
[buy me a coffee](https://buymeacoffee.com/Graeslurk). It's completely
optional: the addon is and will stay free.

## License

All rights reserved, see `LICENSE`.
