# Changelog

All notable changes to rsg-animations. Newest first.

## 3.0.2

### Fixed
- The `favorites_animations` table was never created by the resource, so favourites failed on a database without a manual import. It is now created on start.
### Added
- `Config.AutoDatabase` (default `true`); set `false` to import `installation/rsg-animations.sql` manually.

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
