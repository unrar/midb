# Change Log
All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]
### Added
- New hooks.
- New boolean options `privacy:get`, `privacy:post`, `privacy:put` and `privacy:delete` to specify whether authentication
is needed for these methods. Default: `false`, `true`, `true`, `true`.
- New option `api:getkey` which allows you to set a different key to use in GET requests, if `privacy:get`. Default = `nil`.
To disable this, set it back to nil: `$ midb set api:getkey nil`.
- Exception handling to database operations - after testing, there's no way a request can break or stop the server. The only reason an exception will be risen is due to malformation in JSON files.
- New GET verbs: `/api/endpoint/field` behaves like the normal `/api/endpoint/` but only returns the field specified in
the JSON hash; `/api/endpoint/field/pattern` returns a JSON hash of all the entries where the field matches the pattern
(a regular SQL `LIKE` pattern, by default it's `%pattern%`).
- More verbose output on the server console; more info > less info!

### Changed
- More compacted code in the server engine. Some complicated logics were moved to methods.
- `MIDB::Interface::Server.out_config` made more dynamic and compact.
- Fixed the server engine to ignore everything after the `?` on endpoints to support GET authentication.
- On GET requests, the HMAC **has** to be a digest of the endpoint. For example, if you send a GET request to `/api/users/1` then you have to make a HMAC digest of `users` with the api key. See `client.rb` for an example. Will be explaiend on the wiki when v2 is released.

## [1.1.0] - 2015-11-20
### Added
- New branch ([oop branch]) where this new features are being developed.
- Added new module structure: `MIDB::API::Controller`, `MIDB::API::Dbengine`, `MIDB::API::Hooks`, `MIDB::API::Engine`, `MIDB::Interface::Server` and MIDB::Interface::Errors`.
- New file (`hooks.rb`) that will contain the default content for the hooks (not really implemented yet).
- RSpec tests for the server model.
- Test running at Travis and coverage analysis thru CodeClimate.

### Changed
- Changed `dbengine_model.rb`, `errors_view.rb`, `security_controller.rb`, `server_view.rb`, `server_controller.rb` and `serverengine_controller.rb` to be independent from each other, using a more OOP approach. This will enable developers to customize an API by inheriting from the base MIDB::API classes.
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


[oop branch]: https://github.com/unrar/midb/tree/oop
[Unreleased]: https://github.com/unrar/midb/compare/v1.1.0...HEAD
[1.0.4]: https://github.com/unrar/midb/compare/v1.0.0...v1.0.4
[1.0.5]: https://github.com/unrar/midb/compare/v1.0.4...v1.0.5
[1.1.0]: https://github.com/unrar/midb/compare/v1.0.5...v1.1.0