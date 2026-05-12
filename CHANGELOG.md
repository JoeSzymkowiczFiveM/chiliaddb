
# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [0.2.0] - 2026-05-11

### Added

- `HOOKS.md` — detailed documentation for collection change hooks, including callback signatures, when each hook fires, registration examples via `ChiliadDB.on` and `AddEventHandler`, and a pattern reference.
- `exportCollection` export and `/cdb_exportcollection {collection}` command — exports a single named collection to `{collection}.json` in the resource folder, without touching the rest of the database.
- `importCollection` export and `/cdb_importcollection {collection} {filename}` command — imports a single collection from a JSON file, dropping and replacing any existing collection of the same name.
- `updateOne` export — updates only the first document matching a query and returns its numeric id, or `false` if no match was found.
- `deleteOne` export — deletes only the first document matching a query and returns its numeric id, or `false` if no match was found.
- `replaceOne` export — replaces the entire body of the first matching document with a new document table.
- `count` export — returns the number of documents in a collection matching an optional query; returns the total collection size when no query is provided.
- `collectionExists` export — returns `true` or `false` without side effects, safe to call before any other operation on an untested collection.
- `setCollectionRetention` export — sets or removes a TTL retention policy on a collection; documents older than the policy are pruned on next startup.
- `getCollectionProperties` export — returns the internal metadata for a collection (current index, ids list, retention, etc.).
- `sort` option on `find` — results can now be sorted server-side by any document field in `asc` or `desc` order before `limit` and other options are applied.
- `excludeIndexes`, `excludeFields`, and `includeFields` options on `find` and `findOne` — allow the caller to shape the response without fetching and filtering client-side.

### Changed

- `insert` export renamed to `insertOne` and `insertMany` export renamed to `insert`, aligning the naming scheme with the rest of the API (`updateOne`, `deleteOne`, etc.).
- Performance optimizations

## [0.1.1] - 2025-03-24

This release focused on getting the UI editor to be compatible with the database, and start working on the `aggregate` function.

### Added

- A basic `aggegate` function, that allows you to specify one or more fields to aggregate the data by, and additionally sum a numeric field of values within that grouping. More params will be added to this in the future.

### Changed

- Modified the document and collection lock system to be a bit more granular; the entire collection no longer locks, when we're simply modifying document-level information.

### Fixed

- Several of the UI editing capabilities should now function with the actualy database functions. Document creation and editing should now work. Delete document worked previously.

## [0.1.0] - 2025-03-16

Due to the changes in indexing, you will need to `/cdb_drop` to clear out the database and start from scratch.

### Added

- `insertMany` export to create one or many documents in a single call, within a single collection.
- `renameCollection` export that changes the name of a specified collection. Also added as a command.
- backupDatabase export allows other scripts to trigger a database backup.
- Argument validation on each of the functional exports. Will inform the user if they are not providing the required keys/data to the function.

### Changed

- Indexing system was significantly changed, breaking exports from prior versions.
- Small performance improvement as a result of the change above.
- findOne now returns 2 values; the body and the key of the matched document. If you previously using the resulting value of this function, this shouldn't break anything as the body is still the first returned value.

### Fixed