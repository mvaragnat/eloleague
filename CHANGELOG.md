## 2025-09-10

- Admin tab layout refined on tournament page:
  - Grouped action buttons into an "Actions" card.
  - Moved settings (Require army list at check-in, Non-competitive, Online tournament, Location, Max players) into the "Settings" card.
  - Removed duplicate "Non-competitive (no Elo impact)" toggle from strategy settings.

## 2025-09-09
- Tournaments: add optional `location` with Google Maps embed on Overview; add `online` toggle to hide location fields; add optional `max_players` with registration cap and UI messaging. Editable from Admin tab and creation form. Tests and i18n updated.
## 2025-09-07

- Feature — Game cards on Dashboard and Elo pages now display each player's faction (localized). This provides more context alongside usernames, scores, and ELO changes.

## 2025-09-05
- Admin dashboard with Avo
  - Added Devise-backed `Admin` model (login/logout only; no registrations or password flows)
  - `/avo` restricted to authenticated admins via `authenticate :admin` in routes
  - Avo configured to use `current_admin`, with sign-out pointing to `destroy_admin_session_path`
  - Created resources for Game, Tournament, and Elo models; added corresponding Avo controllers
  - Added integration test ensuring `/avo` is protected and accessible after admin login

Feature — Non-competitive tournaments. Organizer can toggle a tournament as non-competitive (default off). When enabled, tournament games do not affect ELO. Flag propagates to `Tournament::Match` and created `Game::Event` records. Added scopes and UI toggle (new and admin), and overview display. Localized EN/FR. Tests included.

## 2025-09-02

- 2025-09-04: Refactor New Game and Tournament Match forms to share participation fields partial; ensure New Game supports two-player entry and submission; add system test for dashboard game creation.

- Feature — Tournament admin can toggle participant status (pending/checked-in) directly from the Participants tab, regardless of participant requirements (faction or army list). Tab state is now persisted in the URL via `?tab=` and preserved on redirects/updates, so you return to the same tab after actions. Localized labels added.
- Feature — Open tournaments: when organizer clicks "Add game", they can now select Player A and Player B from participants. If the organizer is also registered, they are preselected as Player A by default (can be removed). Form uses Stimulus to select two players, validates factions and scores for both, and populates factions dynamically.

- Feature — Admin tab now includes a Description editor available to the organizer for all tournament formats. Updates auto-save on blur via Stimulus and reflect immediately in the Overview tab. Localized EN/FR.

- 2025-09-05: Feature — Non-competitive tournaments. Organizer can toggle a tournament as non-competitive (default off). When enabled, tournament games do not affect ELO. Flag propagates to `Tournament::Match` and created `Game::Event` records. Added scopes and UI toggle (new and admin), and overview display. Localized EN/FR. Tests included.

## 2025-08-31

- Feature — Army lists for games and tournaments. Optional army list per game participation; tournament registrations can include an army list. New tournament option to require army list at check-in. Army lists hidden before start (except organizer and owner); visible to all once running. UI uses modals; localized in EN/FR.
- Tournaments: Added Overview tab across all formats (description, dates), shows ranking/tie-break strategies and whether army list is required at check-in. Admin can toggle "Require army list at check-in" directly from the Admin tab.
## 2025-08-22

- Add secondary score support for games and tournament matches
- New tie-break strategy: Secondary score sum for Swiss/Open standings
- Update forms and views to capture/display secondary score (compact on tournament pages)

## 2025-08-18

- Add footer rendered on all pages with localized copy and link to a contact page
- Display current user's email next to the logout link in the top navigation
- Implement contact form (subject + message) sending an email via Gmail SMTP (ENV: `GMAIL_USERNAME`, `GMAIL_PASSWORD`, `CONTACT_TO_EMAIL`)

# Changelog

## 2025-08-16
- Replace custom authentication with Devise
  - Added `devise` gem and configured `User` model
  - Migrated `users` to Devise columns; dropped `sessions` table and legacy `email_address`/`password_digest`
  - Replaced custom `Authentication` concern with Devise filters
  - Updated routes, controllers, views, ActionCable connection, and tests
  - Kept i18n messages consistent in EN/FR
- Add localization support for game systems and factions
  - `config/game_systems.yml` now supports `en`/`fr` translations for system names, descriptions, and factions
  - Seeding uses English by default and falls back to French when English is missing
  - Views and dropdowns show localized names via `localized_name`
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
- Tests for bracket builder with 5, 16, and 33 participants (match counts, byes, highest-Elo bye).

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

- 2025-08-31: Add tie-break strategy “Strength of Schedule (SoS)” for Swiss/Open standings, with EN/FR labels and admin UI support.