# Change Log
All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).

## [NEW BRANCH oop]
### Changed
- Changed `dbengine_model.rb`, `errors_view.rb`, `security_controller.rb`, `server_view.rb` and half of `server_controller.rb` to be independent from each other, using a more OOP approach. This will enable developers to customize an API by inheriting from the base MIDB::API classes.
- Added new module structure: `MIDB::API::Controller`, `MIDB::API::Dbengine`, `MIDB::Interface::Server` and MIDB::Interface::Errors`.

## [Unreleased]
### Added
- RSpec tests for the server model.
- Test running at Travis and coverage analysis thru CodeClimate.
### Changed
- Some style changes in hashes. 

## [1.0.5] - 2015-11-07
### Added
- This changelog, to keep the changes of this project.
- New controller, `ServerEngineController` that handles the start of the server engine.

### Changed
- Adding changelog links.
- Broke some methods up so to reduce code complexity (still got a lot of refactoring to do).

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


[NEW BRANCH oop]: https://github.com/unrar/midb/tree/oop
[Unreleased]: https://github.com/unrar/midb/compare/v1.0.4...HEAD
[1.0.4]: https://github.com/unrar/midb/compare/v1.0.0...v1.0.4
[1.0.5]: https://github.com/unrar/midb/compare/v1.0.4...v1.0.5