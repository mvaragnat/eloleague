# frozen_string_literal: true

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

    scope = Game::Event.order(:played_at)
    scope = scope.where(game_system_id: system_id) if scoped

    # Only process events that have exactly two participations
    scope = scope.joins(:game_participations)
                 .group('game_events.id')
                 .having('COUNT(game_participations.id) = 2')

    puts "Recomputing Elo for #{scope.count} events..."
    scope.find_each do |event|
      event.update!(elo_applied: false)
      Elo::Updater.new.update_for_event(event)
    end

    puts 'Done.'
  end
end
