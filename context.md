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
- Create new games with multiple participants
- Real-time player search by username
- Track game results (win/loss/draw)
- Associate games with specific game systems
- Display game history with participants and results
- Use ViewComponent for modular game display
- Exactly two players are required for each game (current user + one opponent). Front-end prevents submission and back-end validates this rule.

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

#### Army Lists
- Players can attach an optional army list when submitting a game; visible to the player via a modal from their game card.
- Tournament registrations support an optional army list editable by the participant and the organizer.
- Tournaments can require an army list at check-in; if enabled, players must provide a list before checking in.
- Visibility: before the tournament starts, only the organizer and the owner can view/edit their list. Once the tournament is running, all visitors (including guests) can view lists from the Participants tab.

#### Elimination Bracket
- On lock, elimination tournaments generate a full bracket tree using `Tournament::BracketBuilder` (Elo-based seeding, power-of-two sizing, byes to top seeds).
- Tree is modeled via `Tournament::Match` with `parent_match_id` and `child_slot`.
- Bracket UI renders from the tree; "Open" link appears only when both players are assigned and the viewer is a participant or the organizer.

#### Swiss/Open Tournaments
Swiss/Open tournaments run in rounds. Closing a round validates all results and generates the next-round pairings from checked-in players (or all registrants if none are checked in). Pairings group players by current points and draw opponents within each group while avoiding repeats when possible. If there is an odd number of players, one player receives a bye for the round, recorded as an immediate win and counted as a played game; byes are assigned among the lowest-scoring eligible players and not given to the same player twice when possible.

Standings award 1 point for a win and 0.5 for a draw. The ranking view lists players by points with tie-breakers applied. Tie-break strategies include primary score sum and secondary score sum. Tournament pages display primary scores prominently; secondary scores are shown compactly where appropriate (e.g., match detail and open format modal).

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

### Footer & Contact
- A global footer appears on all pages: "Made by Marquis with ❤️. A bug, a suggestion, a new game to add? Write me"
- The "Write me" link opens a one-page contact form with subject and message fields
- Submitting the form sends an email to the configured personal address using Gmail SMTP
- Config via ENV:
  - `GMAIL_USERNAME`: Gmail username
  - `GMAIL_PASSWORD`: Gmail app password
  - `CONTACT_TO_EMAIL`: Personal recipient address