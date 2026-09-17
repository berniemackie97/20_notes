# Chat — MsgTalk (1004)

Verified against `Conquer.exe` 5517 on 2026-08-28.

## What the client sends

`Conquer_SendChatInputMessage` (`0x7103CC`) is the only send path behind the chat edit control
(`sub_4a53d3`). It builds every message as:

| Field | Value |
|---|---|
| sender | `CHero+0x14C` — the hero's own name |
| recipient | the literal `"ALL"` |
| suffix | null |
| text | what the player typed, with CR/LF flattened to spaces |
| colour | `0xFFFFFFFF` |
| channel | `chatInput+0xFA`, the tab the player selected |
| style, identity | `0`, `0` |

The client's **directed** sends put a real character name in the recipient instead — the slash
commands in `Conquer_DispatchSlashCommandText` at `0x65A3DD`, `0x65A496`, `0x65A681` and `0x65A853`,
on channels `0x7D2`, `0x7DE` and `0x7E5`.

**So the recipient, not the channel, is what says whether a message is addressed to one person.**
That matters for a server: the channel is a UI selection and carries no guarantee, while `"ALL"` is
the client's own statement that the message is undirected.

## What the client does on receive

`CMsgTalk__Process` (`0x731371`) reads four string entries — sender (`0x10`), recipient (`0x10`),
a third (`0x10`) and the message (`0x100`) — then:

- **`0x7D0` (2000) is rewritten in place to `0x7D7` (2007)** at `0x731450`, before any dispatch.
- `0x835` / `0x834` enqueue into the login and create-role control queues and return. Player text
  must never be relayed on them.
- `0x7D5` renders only when sender is `"SYSTEM"` **and** recipient is the hero's own name.
- `0x836` / `0x838` resolve a role by name and write the text to `role+0x8BC[0x50]`; the client's
  own sender for `0x838` is `sub_70af20`, which also writes the same string on the local hero and
  caps it at `0x40` bytes.
- Everything else falls to the generic tail at `0x732010`: append to the chat log via `sub_5d159a`,
  then `EntityManager_TryFindRoleByName(&g_objPlayerSet, &role, senderName)` and, on a hit, store
  the text on `role+0x3B8` with a `timeGetTime()` stamp.

`sub_5d3f85(chatMgr, channel)` is a per-channel display toggle with cases for `0x7D2`, `0x7D3`,
`0x7D4`, `0x7D6`, `0x7D7`, `0x7D9`, `0x7DE` and `0x7E5`; every other channel always displays.

**The sender is resolved by name, not by the identity field.** The lookup only succeeds for a role
already in the receiver's entity set, so a relayed line attaches to the speaker exactly when the
receiver has been spawned that character.

## What this server does

- Refuses `0x834` / `0x835` outright.
- Overwrites the sender name and identity with the authenticated character's own.
- Echoes every accepted message to its sender: the client renders chat on receive, not on send.
- Handles `0x836`/`0x838` as the role word rather than as chat: the text is recorded on the session,
  echoed to its author, sent to everyone who can see them, and included when the character later
  comes into somebody's view. Over-long text is truncated to `0x40` bytes and the truncated word is
  echoed back, because the author's client has already stored what it sent (`0x70AFD7`) and would
  otherwise be the only one showing it.
- Broadcasts to the speaker's visibility set **only when the recipient is `"ALL"`**. See
  [entity-visibility.md](entity-visibility.md) for that set.
- Routes a directed message to the named character through the server-wide online directory, and
  writes that character's **own spelling** of its name into the recipient field — the client
  compares the recipient against its hero name with `strcmp` (`0x731DD1`), so echoing back what the
  sender typed would not match. A recipient who is not signed in receives nothing.

## Not done

- **No reply when the recipient is offline.** This client build has no proven "that player is not
  online" response for a server to send, so nothing is sent. Inventing one would put text in a chat
  log that the client was never shown.
- **Channel semantics.** Beyond the control channels, `0x7D0`/`0x7D7`, `0x7D5` and `0x836`/`0x838`,
  the meaning of individual channels is not established, so the server neither validates nor
  rewrites the channel a client selects.
- **The role word is session state on both sides.** The server holds it for the session and the
  client holds it on the role object in memory; neither persists it, and nothing in the client asks
  for one back after a reconnect. It is left transient deliberately rather than given storage the
  protocol never restores from.
