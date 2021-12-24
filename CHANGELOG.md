# CHANGELOG

## [v0.3.0]

### Added

- `spec/2` - helper callback function to build custom changesets

### Improvements

- Fixed documentation for custom inline validator

## [v0.2.4]

### Improvements

- Extend support for custom inline validator

## [v0.2.3]

### Improvements

- Added `.formatter.exs` to package

## [v0.2.2]

### Improvements

- Fix embeds_many
- Fix return values for embedded map or array of maps
- Improve docs

## [v0.2.1]

### Improvements

- Simplify `spec` defaults
- Refactor function organization
- Fixes embeds callback

## [v0.2.0]

### Added

- `embeds_one` - support embedding a single map
- `embeds_many` - support embedding list of maps

**Note** - You can always use `{:map, :string}` or `{:array, :map}` as field type if you don't care about validation for the embedded fields.

### Changed

- Use converted params to ensure consistency of map keys

## [v0.1.1]

### Added

- Implement validator callback

## [v0.1.0]

- Added all the things
