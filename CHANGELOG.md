# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2025-01-18]

### Added
- **Factions System**: Complete faction management for games and tournaments
  - Each game system can have multiple factions (e.g., White/Black for Chess)
  - Game participations require faction selection - games cannot be submitted without both players selecting factions
  - Tournament registrations support optional faction selection
  - Players cannot check-in to tournaments without selecting a faction
  - Tournament participants tab includes faction column with dropdown for selection
  - Players can modify their own faction, organizers can modify any participant's faction
  - Full UI integration with validation and error messages
  - Comprehensive test coverage for all faction-related functionality

## [2025-08-13]
- Swiss: Fix pairing to fill the top spot first when score groups are odd, preventing 2 vs 0 pairings when a 2 vs 1 and 1 vs 0 are possible.
- Swiss: Implement deterministic bye assignment for odd participant counts (random among lowest points, avoid repeating same player), recorded as a free win and shown in UI.
- Add tests covering the top-spot fill logic and bye behavior.

## [2025-08-10]

### Added
- Elimination bracket generation on lock:
  - `Tournament::BracketBuilder` service builds the full tree using Elo-based seeding and standard bracket positions.
  - Byes automatically assigned to top seeds and propagated upward.
  - SVG bracket renders from the elimination tree (not rounds) and shows scores when present.
- Tests for bracket builder with 5, 16, and 33 participants (match counts, byes, highest-Elo bye).

### Changed
- “Lock registration” button now reads “Lock registration and generate tournament tree”.
- Elimination Admin panel hides “Generate pairings” and “Close round” (no longer applicable).
- “Open” link on bracket appears only when both players are assigned and the user is eligible.

## [2025-08-09]

### Added
- Tournament feature (MVP):
  - Tournaments browsing (`tournaments#index`) and details page (`tournaments#show`)
  - Tournament creation form (`tournaments#new`, `#create`)
  - Player registration, unregister and check-in actions on tournament page
  - Rounds and Matches pages (index/show) under `tournament/` namespace
  - Basic navigation links to access tournaments from home, dashboard and global nav

## [Unreleased] 

### Added
- Initial Rails project setup with Ruby 3.4.1 and Rails 8.0.1 
- Added RuboCop for code style enforcement 
- Added Kamal 2 deployment configuration => not used
- Created basic landing page with project title "Uniladder"
- Added environment variables configuration system
- Added Docker installation instructions for deployment => not used
- Added core models (User, Game::System, Game::Event) with migrations
- Added basic model and controller tests
- Added authentication system with login functionality
- Added user registration functionality
- Added game creation functionality with player search and modal form
- Added game history display on dashboard with ViewComponent
- Added ViewComponent gem for modular view components

### Changed
- Enforced presence validation for `Game::Participation.result` to prevent saving participations without a result and align with tests
- Updated `Game::EventsController` strong params to require `:event` (was `:game_event`) to match controller tests
- Enforced exactly two players per game at the model level; added distinct-players validation and auto-completion of opponent result
- Added Stimulus `game-form` validation to block submission unless exactly one opponent is selected; added localized error message in EN/FR
- Updated controller and system tests to cover no-players and exactly-two-players scenarios; added i18n messages for success and errors

- Homepage redesign: hero with ork wallpaper background, subtitle, and buttons for browsing tournaments and seeing ELO rankings.