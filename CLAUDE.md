# Eloleague

Project rules live in `.cursorrules` and the functional description in `context.md`: read both before working.
(The "do not run Git commands" and "print the cursorrules version" lines of `.cursorrules` only apply to local Cursor sessions.)

## Design changes: check every domain

The app is served on several domains with different looks: the base site plus the game sites of
`config/game_sites.yml` (`epic_ferc` is dark; `trench_crusade`, `confrontation` and the base site are light),
each with its theme in `app/assets/stylesheets/themes/`. Before proposing any design change:

- Never hardcode a color, font or image in a view, component, inline style or Stimulus controller. Use the
  tokens of the `:root` block of `app/assets/stylesheets/application.css`; if none fits, add one there and set
  it in every theme file.
- Render the changed pages on the base site and on every game site, desktop and mobile, and check text
  contrast on each. Locally: `GAME_SITES="epic.localhost=epic_ferc,tc.localhost=trench_crusade,conf.localhost=confrontation" bin/rails server`,
  then browse `http://epic.localhost:3000`, `http://tc.localhost:3000`, `http://conf.localhost:3000` and `http://localhost:3000`.
- Say in your answer which sites and pages you checked.
- `test/integration/game_site_themes_test.rb` must pass.
- Only use images and fonts we have the rights to. The `trench_crusade` theme must not embed any artwork or
  font of the game or of trenchcrusade.fr.
