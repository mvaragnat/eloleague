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
  - Root entity for a competition. Attributes: `name`, `description`, `creator_id`, `game_system_id`, `format` (open|swiss|elimination), `rounds_count` (for Swiss), `starts_at`, `ends_at`, `state` (draft|registration|running|completed), `settings`.
  - Associations: `has_many :registrations` (participants), `has_many :rounds`, `has_many :matches`.
  - New optional fields: `location` (string) and `online` (boolean, default false). If `online` is true, the address field is hidden and the Overview tab shows an “Online tournament” badge. When `location` is present and `online` is false, the Overview tab displays the address and a small Google Maps embed.
  - New optional `max_players` (integer). When set, registrations are blocked once the number of registrations reaches this cap; UI shows a “Tournament is full” message and the register button is hidden.
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

### Factions System
- Each game system can define multiple factions (e.g., White/Black for Chess, different armies for war games)
- Every game participation must include a faction selection - games cannot be submitted without both players selecting their factions
- Tournament registrations support optional faction selection, but players cannot check-in without choosing a faction
- Tournament participants view includes a faction column with dropdown selection for each player
- Players can modify their own faction; tournament organizers can modify any participant's faction
- Comprehensive validation ensures data integrity across games and tournaments
- Full internationalization support with English and French translations
- Game systems and factions are localized via `config/game_systems.yml` which now contains `en`/`fr` entries for `name`, `description`, and each faction. Database stores the default (English) values; views resolve display through `Game::System#localized_name` and `Game::Faction#localized_name` using `en` by default with `fr` fallback.

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

- Standings award 1 point for a win and 0.5 for a draw. The ranking view lists players by points with tie-breakers applied. Tournament pages display primary scores prominently; secondary scores are shown compactly where appropriate (e.g., match detail and open format modal).

#### Open match reporting
- In Open format, the organizer (or any registered participant when allowed) can add games from the Matches panel. The modal now lets you select Player A and Player B from registered participants.
- If the organizer is also a registered participant, they are preselected as Player A by default but can be removed to enter a different pairing.
- The form uses Stimulus controllers: `player-search` supports selecting two players and `game-form` validates that both players, scores, and factions are provided. Factions are populated dynamically based on the tournament's game system.

- Tie-break strategies in standings:
  - Score sum: sums your reported game scores.
  - Secondary score sum: sums secondary scores across reported games.
  - Strength of Schedule (SoS): sums the final tournament points of your opponents across all your matches. Higher is better.

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

### Footer & Contact
- A global footer appears on all pages: "Made by Marquis with ❤️. A bug, a suggestion, a new game to add? Write me"
- The "Write me" link opens a one-page contact form with subject and message fields
- Submitting the form sends an email to the configured personal address using Gmail SMTP
- Config via ENV:
  - `GMAIL_USERNAME`: Gmail username
  - `GMAIL_PASSWORD`: Gmail app password
  - `CONTACT_TO_EMAIL`: Personal recipient address