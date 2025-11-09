## 2025-11-09

- Tournaments: Added new `cancelled` state.
  - Cancelled tournaments are hidden from all index tabs (Accepting, Ongoing, Closed) and only visible under “My tournaments”.
  - EN/FR translations added.
  - Tests updated to cover visibility rules.

## 2025-11-05

- Swiss/Open: Added pairing strategy "By ranking order (avoid repeats)".
  - Pairs players strictly by current standings order (primary and tie-breakers): 1v2, 3v4, ...
  - If a neighbor pair already played, the generator tries a one-position shift (1v3 and 2v4) to avoid repeats.
  - Strategy selectable in the tournament Admin tab; fully localized (EN/FR).

## 2025-10-31

- Stats panel is now available to all authenticated users (not admin-only).
- Global faction winrates table defaults to sorting by Win% (descending).

## 2025-10-17

- Add admin-only Stats page:
- Add new game system: OPR Grimdark Future
  - Seeded from `config/game_systems.yml` with factions sourced from the Army Forge "Official books" for Grimdark Future.
  - See reference: [Army Forge Grimdark Future](https://army-forge.onepagerules.com/armyBookSelection?gameSystem=gf)
  - Docs updated in `context.md`. Seeding tests updated to compute counts dynamically from YAML.
  - System selector shows per-faction win rates table (sortable). Mirrors counted in totals but excluded from W/L/D and Win%.
  - Faction selector shows winrate-over-time graph and versus table against all factions (sortable). Mirror row shows only mirror count.
  - Uses Stimulus and importmap; localized EN/FR.

## 2025-10-21

## 2025-10-23

- Avo: Fix deletion of Game Event and Tournament Match (avoid querying non-existent tournament_matches.event_id) by clarifying FK on `Game::Event` → `Tournament::Match`.
- Swiss/Open: Ranking table now shows the Secondary score sum column only when 'Secondary score sum' is selected as primary or a tie-break strategy.
- Tournament Match form: Show Secondary score inputs only when 'Secondary score sum' is selected as a tie-break/primary.
- My Dashboard → New Game: Hide Secondary score fields (secondary is tournament-only).

- Stats: Show only statistically significant rows
  - Add ENV-configurable thresholds `STATS_MIN_PLAYERS` (default 4) and `STATS_MIN_GAMES` (default 10)
  - Global faction winrate table and faction vs table now hide rows unless counts are strictly greater than thresholds
  - Non-competitive games excluded from all stats (tables and time series)
  - Added explanatory note on the Stats page with localized copy (EN/FR)

## 2025-10-26

- Feature — Email notifications for players (EN/FR):
  - Notify when a casual Game event is recorded for a user by someone else (opponent-submitted game)
  - Notify when a new Swiss round creates a Tournament match for a user
  - Notify when a Tournament match result is recorded by someone else (avoids duplicate with Game event)
  - Notify all participants when a Tournament is finalized, including Top 3 player names
  - Links to the relevant Tournament or My Dashboard, plus a contact link
  - Fully localized (English/French)
  - Implementation: `UserNotificationMailer`, `UserNotifications::Notifier`, hooks in `Game::Event`, `Tournament::Match`, and finalize action
  - Tests added for mailer and standings Top 3 extraction

## 2025-10-16
- Add Player profile page (`/users/:id`) with:
  - Current ELO by game system
  - ELO over time multi-series chart (per game system)
  - Full list of the player's games
- Link player profile from Elo standings, tournament participants, and ranking tables
## 2025-10-15

- Avo: Removed ELO resources and `GameEvent` ELO relation (Avo free plan limitation workaround).
- Avo: `GameFaction` index now sortable by “Games played” via counter cache.
- Avo: `Tournament` index shows registrations count via counter cache.
- Avo: Sorted `User` selections alphabetically; scoped `Faction` selections to the relevant game system on `GameParticipation` and `TournamentRegistration`.
- UX: Player search results sorted A→Z; tournament match modal loads initial factions ordered A→Z.
## 2025-10-13

- Open tournaments: organizer preselected as Player A if registered (removable)
  - In the Open format match modal, participants still see themselves preselected as Player A and cannot remove themselves
  - Organizers who are registered are preselected as Player A but can unselect themselves to pick any two registered players; if not registered, no preselection
  - Server-side guard: non-organizers must include themselves among the two selected players; organizers are exempt
  - Updated tests to cover organizer and participant flows; fixed escaping in SoS header highlight test

## 2025-10-05

- Fixed Avo Tournament Registration creation from tournament page
  - Creating a new tournament registration from Avo now works correctly when using slug-based tournament URLs
  - Fixed `find_record` method in Tournament Avo resource to be a class method (was incorrectly defined as instance method)
  - Added integration test to verify both slug and ID-based registration creation
  
## 2025-10-03

- Add new game system: Epic UK
  - Seeded from `config/game_systems.yml` with factions sourced from Epic UK official army lists.
  - Factions are English-only per requirement (no FR translations).
  - Docs updated in `context.md`. Tests adjusted for new counts.

## 2025-10-02

- Tournament slug URLs
  - All tournaments now have a URL-friendly slug based on their title (generated at creation)
- Slugs normalize names: convert to lowercase, replace spaces and hyphens with underscores, remove special characters, replace accents with similar non-accented letters
  - Tournament URLs now use slugs instead of database IDs for better SEO and readability (e.g., `/tournaments/spring-championship-2025`)
  - Backward compatibility maintained: tournaments can still be accessed by ID
  - Slug is immutable after creation; changing the tournament name does not update the slug
  - Admin form displays a warning notice when editing tournament names
  - Rake task added to backfill slugs for existing tournaments without slugs
  - Full test coverage and localization (EN/FR)

## 2025-10-03

- Avo admin: add search by username on Users resource index.

## 2025-10-01

- Swiss tournaments: Added "Score for bye" option
  - Organizers can set a score value (default 0) that bye players receive in their score_sum
  - Configurable in Admin tab (Swiss tournaments only)
  - Displayed in tournament Settings/Overview tab
  - Previously, byes awarded 1.0 points but 0 score, causing ranking issues when using score as primary criterion
  - Now organizers can set an appropriate bye score (e.g., match the average game score) for fair rankings

## [Unreleased] - 2025-09-29

- Avo admin dashboard updates:
  - Game Factions: added filter by Game System, sortable Name column, and a Games Played column showing number of participations per faction.
  - Game Factions: added bulk delete action to remove multiple selected factions in one click (with confirmation and EN/FR i18n).
  - New users created by admins now auto-generate a secure random password if left blank (fixes "password can't be blank").
  - Usernames are displayed across Tournament Matches, Registrations, Elo Ratings, and Elo Changes via proper belongs_to association titles.
  - Removed separate sidebar entries for Game Participation and Tournament Rounds in Avo.
  - Game Events display a participants summary with usernames and scores.

## 2025-09-18

- Tournament: organizers can edit reported matches
  - Editing updates the existing Game::Event (no new Elo application)
  - Swiss: existing generated next-round pairings remain unchanged
  - Elimination: parent assignment updates only if the next match has not been played

- Feature — Organizer can swap pairings for unplayed matches in Swiss and Elimination:
  - On the match page, the A/B player names become admin-only dropdowns listing eligible players from the same round/depth with pending matches.
  - Selecting a player and clicking "Switch" swaps players across the two affected matches.
  - Backend validation ensures swaps only occur within the same round (Swiss) or same depth level (Elimination), and only for matches without results.
  - Fully localized (EN/FR), with controller tests for both formats.


## 2025-09-10

- Admin tab layout refined on tournament page:
  - Grouped action buttons into an "Actions" card.
  - Moved settings (Require army list at check-in, Non-competitive, Online tournament, Location, Max players) into the "Settings" card.
  - Removed duplicate "Non-competitive (no Elo impact)" toggle from strategy settings.
  - Overview tab now mirrors Admin: split into "Info" (status, description, format, localization) and "Settings" (dates, tie-breaks, army list requirement, non-competitive, max players).

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

## 2025-09-18
- Add customizable primary ranking strategy for tournament standings (default: Points). Primary can use same strategies as tie-breakers (Points, Score sum, Secondary score sum, SoS). Updated admin settings UI, overview and ranking table, plus i18n (EN/FR). Added migration and tests.

## 2025-09-19
- Ranking tab now shows all relevant columns: Points, Score sum, Strength of Schedule (SoS), and Secondary score sum. Columns selected as primary or tie-break criteria are highlighted in pale yellow. Added EN/FR translations and tests.

- ELO page: add server-side pagination of standings with localized controls; default to the page containing the signed-in user (if rated) and bold their username in the table. Tests and docs updated.