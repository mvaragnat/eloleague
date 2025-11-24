# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
namespace :scoring do
  desc 'Backfill scoring_system_id on past tournaments and game events using system defaults'
  task backfill_defaults: :environment do
    puts '[scoring] Backfilling default scoring systems...'

    updated_tournaments = 0
    Tournament::Tournament.where(scoring_system_id: nil).find_each do |t|
      default = Game::ScoringSystem.default_for(t.game_system)
      next unless default

      # Bypass validations to update legacy rows safely
      t.update_columns(scoring_system_id: default.id, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
      updated_tournaments += 1
    end
    puts "[scoring] Updated tournaments: #{updated_tournaments}"

    updated_events = 0
    Game::Event.where(scoring_system_id: nil).includes(:tournament, :game_system).find_each do |ev|
      scoring = ev.tournament&.scoring_system || Game::ScoringSystem.default_for(ev.game_system)
      next unless scoring

      ev.update_columns(scoring_system_id: scoring.id, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
      updated_events += 1
    end
    puts "[scoring] Updated game events: #{updated_events}"

    # Recalculate match results according to the attached scoring system
    updated_matches = 0
    Tournament::Match
      .includes(:tournament, game_event: { game_participations: :user })
      .where.not(game_event_id: nil)
      .find_each do |m|
        scoring = m.tournament&.scoring_system || m.game_event&.scoring_system
        next unless scoring

        pa = m.game_event.game_participations.find_by(user_id: m.a_user_id)
        pb = m.game_event.game_participations.find_by(user_id: m.b_user_id)
        next unless pa && pb && !pa.score.nil? && !pb.score.nil?

        new_result = scoring.result_for(pa.score, pb.score)
        # Elimination brackets cannot be draws; skip converting to draw there
        next if m.tournament&.elimination? && new_result == 'draw'

        next if m.result == new_result

        m.update_columns(result: new_result, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
        updated_matches += 1
      end
    puts "[scoring] Updated tournament matches: #{updated_matches}"

    puts '[scoring] Backfill complete.'
  end
end
# rubocop:enable Metrics/BlockLength
