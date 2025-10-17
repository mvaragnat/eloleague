# Uniladder

## Overview
Uniladder is a game tracking and ranking app. Players can track their games and see their rankings across different game systems.

## Core Models

### User (Player)
- Represents a player in the system
- Has many game events (participations)

### Game::System
- Represents a game system (e.g., Chess, Go, Magic: The Gathering)
- Has many game events
- Has many players through game events
- Has many factions

### Game::Faction
- Represents a faction/side within a game system (e.g., White/Black for Chess)
- Belongs to a game system
- Has many game participations
- Required for all game participations

### Game::Event
- Represents a single game played
- Belongs to a game system
- Has many players (through participations)
- Tracks the outcome of the game
 - Each participation now supports a secondary score used for tie-breaks
 - Each participation can include an optional army list (text)

### Tournament Domain
- `Tournament::Tournament`
  - Root entity for a competition. Attributes: `name`, `description`, `creator_id`, `game_system_id`, `format` (open|swiss|elimination), `rounds_count` (for Swiss), `starts_at`, `ends_at`, `state` (draft|registration|running|completed), `settings`, `slug`.
  - Associations: `has_many :registrations` (participants), `has_many :rounds`, `has_many :matches`.
  - New optional fields: `location` (string) and `online` (boolean, default false). If `online` is true, the address field is hidden and the Overview tab shows an "Online tournament" badge. When `location` is present and `online` is false, the Overview tab displays the address and a small Google Maps embed.
  - New optional `max_players` (integer). When set, registrations are blocked once the number of registrations reaches this cap; UI shows a "Tournament is full" message and the register button is hidden.
  - `slug` (string, unique): URL-friendly identifier generated automatically from the tournament name at creation. Normalizes to lowercase, replaces spaces with underscores, removes special characters, and replaces accents. Once set, the slug never changes even if the tournament name is updated. Tournament routes use slug instead of ID for better SEO. The admin form shows a warning that changing the name won't update the slug.
- `Tournament::Registration`
  - Join between a `Tournament::Tournament` and a `User` with optional `seed` (Elo snapshot), `status` (`pending|approved|checked_in`), and optional `faction_id`.
  - Optional `army_list` (text) per registration.
  - Unique per (tournament, user).
- `Tournament::Round`
  - Represents a numbered round within a tournament (`number`, `state`), mainly used by Swiss/Open formats.
  - `has_many :matches` in that round.
- `Tournament::Match`
  - The scheduled pairing inside a tournament; optional link to a `Game::Event` when reported.
  - Attributes: `a_user_id`, `b_user_id`, `result` (`a_win|b_win|draw|pending`), optional `tournament_round_id` (for Swiss/Open), and for elimination only: `parent_match_id`, `child_slot`.

## Features

### Authentication & User Management
- Devise-based authentication (email/password)
- Registration, login/logout, password reset
- `current_user` (Devise) mirrored to `Current.user` for app usage
- Custom login and signup pages styled with `AuthCardComponent`, following app-wide layout and localization
- Password reset and change pages styled consistently with `AuthCardComponent` and localized texts

### Game Management
- Create new games with exactly two participants via a unified two-block form shared with Tournament Open matches
- Real-time player search by username
- Track game results (win/loss/draw)
- Associate games with specific game systems
- Display game history with participants and results
- Use ViewComponent for modular game display
- Exactly two players are required for each game. The form provides two independent player selectors; front-end prevents submission unless both players, scores, and factions are provided; back-end enforces the same validations.
- Game cards on the Dashboard and Elo pages display each player's faction (localized) beneath their username.

### Player Profile Page
- Public page at `/users/:id` showing a player's cross-system profile
- Sections:
  - Current ELO by game system (rating and games played)
  - ELO over time chart (one color per game system)
  - All games played by the user across systems (same card component used elsewhere)
- Profile links are available from Elo standings, tournament participants, and tournament ranking tables.

### ELO Rankings Page
- `/elo` lists player ELO standings per selected game system.
- Standings are server-paginated (default 25 per page; configurable via `?per=`, max 100).
- When a user is signed in and has a rating for the selected system, the default page is the one containing the user; their username is bolded in the table.
- Pagination controls are localized (EN/FR) and preserve the selected game system.

### Factions System
- Each game system can define multiple factions (e.g., White/Black for Chess, different armies for war games)
- Every game participation must include a faction selection - games cannot be submitted without both players selecting their factions
- Tournament registrations support optional faction selection, but players cannot check-in without choosing a faction
- Tournament participants view includes a faction column with dropdown selection for each player
- Players can modify their own faction; tournament organizers can modify any participant's faction
- Comprehensive validation ensures data integrity across games and tournaments
- Full internationalization support with English and French translations
- Game systems and factions are localized via `config/game_systems.yml` which now contains `en`/`fr` entries for `name`, `description`, and each faction. Database stores the default (English) values; views resolve display through `Game::System#localized_name` and `Game::Faction#localized_name` using `en` by default with `fr` fallback.

### Stats (Admin-only)
- Admins can access a `Stats` page (`/stats`) to explore per-system and per-faction performance.
- Selecting a game system reveals a sortable table of all factions with: total games (including mirrors), unique players, Wins, Losses, Draws, and Win% (mirrors excluded from W/L/D and Win%).
- Selecting a faction shows:
  - A winrate-over-time graph with the same visual style as the ELO chart.
  - A sortable versus table against all factions in the system, with mirror games shown only as a count.

#### Epic UK Game System
- Added `Epic UK` as a supported game system with factions sourced from the official Epic UK army lists. See [Epic UK Army Lists](https://epic-uk.co.uk/wp/army-lists/).
- Factions for `Epic UK` are provided in English only; French translations are not required for these factions.

### Tournaments
- Create and browse tournaments by game system and format (open, swiss, elimination)
- Register/unregister and check-in to tournaments
- View tournament rounds and matches; update match results
- Admin actions for the tournament creator: lock registration, generate pairings, close round, finalize
- Tournament games integrate with Elo the same way as casual games

#### Competitive vs Non-competitive Tournaments
- Organizers can mark a tournament as non-competitive. Default is competitive.
- When non-competitive, reported tournament games do not affect ELO.
- The non-competitive flag is copied down to all `Tournament::Match` records and created `Game::Event` records.
- Scopes exist to filter competitive vs non-competitive on tournaments, matches, and events.

#### Admin Check-in Toggle & Tab Persistence
- The organizer can toggle any participant status between `pending` and `checked_in` from the `Participants` tab, bypassing participant requirements (faction selection or army list submission). This is intended for day-of check-in adjustments.
- The tournaments page persists the selected tab in the URL using the `tab` query parameter and keeps the same tab active after updates and redirects.

#### Overview Tab
- All tournament formats include an Overview tab summarizing key details:
  - Description
  - Dates (start/end)
  - Ranking tie-break strategies (primary and secondary)
  - Whether an army list is required at check-in
- The organizer can edit the tournament Description from the Admin tab and toggle the "Require army list at check-in" option; changes apply immediately (autosaved on blur).

#### Army Lists
- Players can attach an optional army list when submitting a game; visible to the player via a modal from their game card.
- Tournament registrations support an optional army list editable by the participant and the organizer.
- Tournaments can require an army list at check-in; if enabled, players must provide a list before checking in.
- Visibility: before the tournament starts, only the organizer and the owner can view/edit their list. Once the tournament is running, all visitors (including guests) can view lists from the Participants tab.

#### Elimination Bracket
- On lock, elimination tournaments generate a full bracket tree using `Tournament::BracketBuilder` (Elo-based seeding, power-of-two sizing, byes to top seeds).
- Tree is modeled via `Tournament::Match` with `parent_match_id` and `child_slot`.
- Bracket UI renders from the tree; "Open" link appears only when both players are assigned and the user is eligible.

#### Post-report Match Edits
- Organizers can edit a match after it has been reported.
- Editing updates the existing `Game::Event` (scores/secondary scores) rather than creating a new event; Elo is therefore not re-applied (use the `elo:rebuild` task if ratings must be recomputed).
- Swiss: if a subsequent round has already been generated, its pairings remain unchanged when editing a previous round.
- Elimination: changing the winner updates the assigned player on the parent match only if that parent match has not been played yet; if the parent has already been reported/played, the bracket remains unchanged.

#### Swiss/Open Tournaments
- Swiss/Open tournaments run in rounds. Closing a round validates all results and generates the next-round pairings from checked-in players (or all registrants if none are checked in). Pairings group players by current points and draw opponents within each group while avoiding repeats when possible. If there is an odd number of players, one player receives a bye for the round, recorded as an immediate win and counted as a played game; byes are assigned among the lowest-scoring eligible players and not given to the same player twice when possible.

- Standings award 1 point for a win and 0.5 for a draw. The ranking view lists players by the selected primary strategy with tie-breakers applied. The Ranking tab shows four columns: Points, Score sum, Strength of Schedule (SoS), and Secondary score sum. Columns that correspond to the selected primary or tie-break strategies are highlighted in pale yellow to make the applied rules explicit.

- Swiss tournaments support a "Score for bye" setting (integer, default 0) that determines the score value awarded to players receiving a bye. This score is included in their score_sum for tie-breaking and rankings. Organizers can configure this in the Admin tab, and it is displayed in the tournament's Overview tab.

#### Pairing swap (Swiss & Elimination)
- The tournament organizer can adjust pairings for unplayed matches directly from the match page.
- For Swiss, eligible swap targets are players from other unreported matches within the same round.
- For Elimination, eligible swap targets are players from other unreported matches at the same depth level in the bracket (i.e., same round of the tree).
- Swapping is symmetric: selecting a player in the dropdown performs a swap between the two affected matches.
- Security/validation: only the organizer can swap; only pending matches are eligible; swaps are constrained to the same round/depth.

#### Open match reporting
- In Open format, the organizer (or any registered participant when allowed) can add games from the Matches panel. The modal lets you select Player A and Player B from registered participants.
- Participant flow: when a normal participant opens the modal, they are preselected as Player A and cannot remove themselves (ensures they report their own match).
- Organizer flow: when the organizer opens the modal and is registered, they are preselected as Player A but can remove themselves to select any other pairing. If the organizer is not registered, no preselection.
- The form uses Stimulus controllers: `player-search` supports selecting two players and `game-form` validates that both players, scores, and factions are provided. Factions are populated dynamically based on the tournament's game system.

- Tie-break strategies in standings:
  - Score sum: sums your reported game scores.
  - Secondary score sum: sums secondary scores across reported games.
  - Strength of Schedule (SoS): sums the final tournament points of your opponents across all your matches. Higher is better.

- Primary ranking strategy for standings is customizable (default: Points). Supported options mirror tie-breakers:
  - Points: win=1, draw=0.5, loss=0
  - Score sum
  - Secondary score sum
  - Strength of Schedule (SoS)
  The Admin tab includes a dropdown for Primary with localized explanations; Overview and Ranking reflect the selected strategy.

### Homepage
- Hero section with background image (`public/ork-wallpaper.jpg`), localized subtitle, and buttons to browse tournaments and see ELO rankings.

### Internationalization
- Full support for multiple languages
- English and French translations available
- Language selection via UI

### Technical Features
- Modern Rails 8.0.1 application
- RuboCop code style enforcement
- Comprehensive test coverage
- Environment variables configuration
- Hotwire for dynamic interactions
- Stimulus for JavaScript functionality
- Responsive design with Tailwind CSS 

### Admin Dashboard (Avo)
- Avo admin dashboard is mounted at `/avo` and is restricted to authenticated Admins only.
- Authentication uses Devise `Admin` model (login/logout only; sign-up and password routes are disabled).
- Avo reads the current admin via `current_admin` and redirects unauthenticated access to `/admins/sign_in`.
- Sign-out link in Avo targets the Admin session destroy path.
- See Avo authentication reference used for setup: Avo 3 Authentication.

- Admin-created users: when creating a User from Avo and leaving password blank, the system auto-generates a secure random password.
- Avo menu hides `Game::Participation` and `Tournament::Round` resources; still accessible via relations.
- Game Events list/show display a participants summary (usernames and scores). Participants are visible as related records.
- ELO-specific Avo resources are removed from the sidebar; ELO data remains in the app but is not navigable via Avo.
- Game Factions index can be sorted by Games played.
- Tournament index shows a Registrations count column.

- Users resource: supports searching by `username` on the index page.

- Game Factions resource:
  - Index supports filtering by Game System.
  - `name` is sortable.
  - Displays a read-only "Games played" column showing the number of participations for that faction.
  - Supports selecting multiple factions and deleting them at once via a bulk delete action with confirmation (EN/FR localized).

- Tournament resource:
  - The `find_record` class method is overridden to support slug-based lookups in addition to ID-based lookups.
  - This enables creating tournament registrations and accessing related resources via slug URLs (e.g., when clicking "Add Registration" from a tournament page).

### Footer & Contact
- A global footer appears on all pages: "Made by Marquis with ❤️. A bug, a suggestion, a new game to add? Write me"
- The "Write me" link opens a one-page contact form with subject and message fields
- Submitting the form sends an email to the configured personal address using Gmail SMTP
- Config via ENV:
  - `GMAIL_USERNAME`: Gmail username
  - `GMAIL_PASSWORD`: Gmail app password
  - `CONTACT_TO_EMAIL`: Personal recipient address