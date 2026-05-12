# ChiliadDB — Collection Change Hooks

Collection change hooks let you react to database writes in real time, without polling. Any server-side resource can listen for inserts, updates, and deletes on any collection.

---

## Overview

Every write operation in ChiliadDB fires a server event immediately after the write completes:

```
chiliaddb:hook:<collection>:<event>
```

| Operation | Hook | Callback signature | Notes |
|---|---|---|---|
| `insert` | `insert` | `function(ids, documents)` | Fires once after all documents are inserted; `ids` and `documents` are arrays |
| `insertOne` | `insert` | `function(id, document)` | Fires once after the document is inserted |
| `update` | `update` | `function(ids, documents)` | Fires once after all matched documents are updated; `ids` and `documents` are arrays; fires `insert` instead when an upsert creates a new document |
| `updateOne` | `update` | `function(id, document)` | Fires once after the first matched document is updated |
| `replaceOne` | `update` | `function(id, document)` | Fires once after the first matched document is replaced |
| `delete` | `delete` | `function(ids, deletedDocuments)` | Fires once after all matched documents are deleted; `ids` and `deletedDocuments` are arrays |
| `deleteOne` | `delete` | `function(id, deletedDocument)` | Fires once after the first matched document is deleted |

---

## Registering hooks

Hooks are fired using FiveM's server-side `TriggerEvent`, which broadcasts globally across all resources. This means **any resource** — regardless of whether it was the one that performed the write — will receive the event, as long as it has a handler registered.

### Via `ChiliadDB.on` (recommended)

Available in any resource that imports `ChiliadDB`. Internally this is just a thin wrapper around `AddEventHandler`.

```lua
ChiliadDB.on(collection, event, callback)
```

```lua
-- Fire whenever a player document is inserted
ChiliadDB.on('players', 'insert', function(id, document)
    print(string.format('Player %s joined (id: %d)', document.name, id))
end)

-- Fire whenever player documents are updated
ChiliadDB.on('players', 'update', function(ids, documents)
    for i = 1, #ids do
        TriggerClientEvent('myresource:statsUpdated', -1, ids[i], documents[i])
    end
end)

-- Fire whenever one or more player documents are deleted
ChiliadDB.on('players', 'delete', function(ids, deletedDocuments)
    for i = 1, #ids do
        print(string.format('Player %s removed (id: %d)', deletedDocuments[i].name, ids[i]))
    end
end)
```

---

### Via `AddEventHandler` (any resource)

Equivalent to `ChiliadDB.on` — use this if your resource does not import `ChiliadDB`, or if you prefer the raw FiveM API. Both approaches receive the same events from the same sources.

```lua
AddEventHandler('chiliaddb:hook:players:insert', function(id, document)
    -- react to a new player document
end)

AddEventHandler('chiliaddb:hook:players:update', function(ids, documents)
    -- react to player documents being updated
end)

---

## Examples

### Broadcast a leaderboard update to all clients

```lua
ChiliadDB.on('leaderboard', 'update', function(ids, documents)
    for i = 1, #ids do
        TriggerClientEvent('leaderboard:refresh', -1, ids[i], documents[i])
    end
end)
```

### Log all deletions from the `logs` collection

```lua
ChiliadDB.on('logs', 'delete', function(ids, deletedDocuments)
    for i = 1, #ids do
        lib.print.info(string.format('[ChiliadDB] Log entry %d deleted: %s', ids[i], json.encode(deletedDocuments[i])))
    end
end)
```

### Notify a Discord webhook when a new vehicle is registered

```lua
ChiliadDB.on('vehicles', 'insert', function(id, document)
    -- call your webhook helper, etc.
    DiscordLog('New vehicle registered', string.format('ID: %d | Owner: %s', id, document.owner))
end)
```

### Listen from a separate resource without `ChiliadDB` integration

```lua
-- In myresource/server.lua — no ChiliadDB dependency needed
AddEventHandler('chiliaddb:hook:players:insert', function(id, document)
    exports['myresource']:onPlayerCreated(id, document)
end)
```

---

## Event name pattern

```
chiliaddb:hook:<collection>:<event>
```

| Placeholder | Values |
|---|---|
| `<collection>` | Exact collection name (e.g. `players`, `vehicles`) |
| `<event>` | `insert`, `update`, or `delete` |
