# Change Log
All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]
### Added
- This changelog, to keep the changes of this project.
### Changed
- Adding changelog links.

## [1.0.4] - 2015-11-05
### Added
- `length()` method to the `Dbengine` model, that discriminates between SQLite3 and MySQL.

### Changed
- Created new gem version.
- Updated Rakefile for new version.

### Fixed
- Fixed some bugs that didn't (properly) discriminate between MySQL and SQLite3 in the server model.
- Other bug fixes.

### Removed
- Cleaned up old gem files.


[Unreleased]: https://github.com/unrar/midb/compare/v1.0.4...HEAD
[1.0.4]: https://github.com/unrar/midb/compare/v1.0.0...v1.0.4