# frozen_string_literal: true

namespace :elo do
  desc 'Rebuild Elo ratings from all events (optionally for a system: SYSTEM_ID=ID)'
  # heroku run rails elo:rebuild --app uniladder
  task :rebuild, [:game_system] => [:environment] do |_task, args|
    system_id = args[:game_system].to_i if args && args[:game_system]
    scoped = system_id.present? && system_id.positive?
    puts(scoped ? "Scoped rebuild for game_system_id=#{system_id}" : 'Global rebuild for all systems')

    count = Elo::Rebuilder.new(game_system_id: scoped ? system_id : nil).call
    puts "Recomputed Elo for #{count} events..."
  end
end
