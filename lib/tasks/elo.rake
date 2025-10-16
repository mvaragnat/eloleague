# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
namespace :elo do
  desc 'Rebuild Elo ratings from all events (optionally for a system: SYSTEM_ID=ID)'
  # heroku run rails elo:rebuild --app uniladder
  task :rebuild, [:game_system] => [:environment] do |_task, args|
    system_id = args[:game_system].to_i if args && args[:game_system]
    scoped = system_id.present? && system_id.positive?

    if scoped
      puts "Scoped rebuild for game_system_id=#{system_id}"
      EloRating.where(game_system_id: system_id).delete_all
      EloChange.where(game_system_id: system_id).delete_all
    else
      puts 'Global rebuild for all systems'
      EloRating.delete_all
      EloChange.delete_all
    end

    # Use explicit ordering and batch pagination without find_each to respect order
    scope = Game::Event.order(played_at: :asc, id: :asc)
    scope = scope.where(game_system_id: system_id) if scoped

    # Only process events that have exactly two participations
    scope = scope.joins(:game_participations)
                 .group('game_events.id')
                 .having('COUNT(game_participations.id) = 2')

    # Iterate in chunks to avoid loading everything, but keep order
    batch_size = 1000
    offset = 0
    updater = Elo::Updater.new
    count = 0
    loop do
      batch = scope.limit(batch_size).offset(offset).to_a
      break if batch.empty?

      batch.each do |event|
        event.update!(elo_applied: false)
        updater.update_for_event(event)
        count += 1
      end

      offset += batch_size
    end

    puts "Recomputed Elo for #{count} events..."
  end
end
# rubocop:enable Metrics/BlockLength
