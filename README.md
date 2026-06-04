# Uniladder

A modern web application built with Rails 8.0.1.

## Installation

1. Clone the repository
2. Install dependencies: 
```bash
bundle install
```
3. Set up environment variables: 
```bash
cp .env.template .env
# Edit .env with your values
```

## Environment Variables

The following environment variables are required:

- `DATABASE_URL`: PostgreSQL connection URL
- `RAILS_MASTER_KEY`: Rails master key for credentials
- `APP_HOST`: Application host (e.g., localhost:3000)
- `KAMAL_REGISTRY_PASSWORD`: Docker registry password (for deployment)

## Development

1. Set up your environment variables
2. Start the server: 
```bash
bin/dev
```

## API

Public JSON endpoints under `/api`. No authentication required. Responses use `Content-Type: application/json`.

Path parameters:

| Parameter | Description |
|-----------|-------------|
| `game_system_id` | Numeric ID of a `Game::System` (e.g. from the admin UI or database) |
| `year` | Calendar year for championship standings (integer) |

### Championship rankings

```
GET /api/championships/:game_system_id/year/:year
```

Returns annual championship standings for the given game system and year. Rankings are sorted by total points (descending), then username. Players with the same total share the same rank.

**200 OK**

```json
{
  "game_system": "Chess",
  "year": 2026,
  "rankings": [
    {
      "rank": 1,
      "username": "alice",
      "total_points": 16,
      "match_points": 0,
      "placement_bonus": 16,
      "tournaments_count": 2
    }
  ]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `game_system` | string | Internal game system name |
| `year` | integer | Requested year |
| `rankings` | array | Ordered list of players (may be empty) |
| `rankings[].rank` | integer | Position (ties share the same rank) |
| `rankings[].username` | string | Player username |
| `rankings[].total_points` | integer | Sum of championship points for the year |
| `rankings[].match_points` | integer | Always `0` (legacy field; scoring is placement-based) |
| `rankings[].placement_bonus` | integer | Sum of placement/participation points from tournament levels |
| `rankings[].tournaments_count` | integer | Number of counted tournaments |

**404 Not Found** — unknown `game_system_id`:

```json
{ "error": "game_system not found" }
```

### Finished tournaments

```
GET /api/tournaments/:game_system_id/finished
```

Returns completed tournaments for the game system, newest `starts_at` first. Cancelled tournaments are excluded.

**200 OK** — JSON array:

```json
[
  {
    "name": "Summer Swiss 2026",
    "slug": "summer-swiss-2026",
    "url": "http://localhost:3000/en/tournaments/summer-swiss-2026",
    "state": "completed",
    "format": "swiss",
    "starts_at": "2026-06-01T10:00:00.000+02:00",
    "ends_at": "2026-06-02T18:00:00.000+02:00"
  }
]
```

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Tournament name |
| `slug` | string | URL slug |
| `url` | string | Full link to the tournament page (default locale) |
| `state` | string | `completed` |
| `format` | string | `open`, `swiss`, or `elimination` |
| `starts_at` | string \| null | ISO 8601 datetime |
| `ends_at` | string \| null | ISO 8601 datetime |

**404 Not Found** — unknown `game_system_id`:

```json
{ "error": "game_system not found" }
```

### Open tournaments

```
GET /api/tournaments/:game_system_id/open
```

Returns tournaments that are accepting signups or in progress (`registration` or `running`), newest `starts_at` first. Cancelled tournaments are excluded.

**200 OK** — same array shape as finished tournaments; `state` is `registration` or `running`.

**404 Not Found** — same error body as finished tournaments.

## Deployment

Deployment is handled by Kamal 2. Make sure all environment variables are properly set in your deployment environment.