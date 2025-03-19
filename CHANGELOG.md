
# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [0.1.0] - 2025-03-16

Due to the changes in indexing, you will need to `/cdb_drop` to clear out the database and start from scratch.

### Added

- insertMany export to create one or many documents in a single call, within a single collection.
- renameCollection export that changes the name of a specified collection. Also added as a command.
- backupDatabase export allows other scripts to trigger a database backup.
- Argument validation on each of the functional exports. Will inform the user if they are not providing the required keys/data to the function.

### Changed

- Indexing system was significantly changed, breaking exports from prior versions.
- Small performance improvement as a result of the change above.
- findOne now returns 2 values; the body and the key of the matched document. If you previously using the resulting value of this function, this shouldn't break anything as the body is still the first returned value.

### Fixed