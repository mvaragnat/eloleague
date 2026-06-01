# frozen_string_literal: true

namespace :championship do
  desc 'Recalculate scores. Usage: championship:recalculate / championship:recalculate[2026]'
  task :recalculate, [:year] => [:environment] do |_task, args|
    tournaments = Tournament::Tournament
                  .where(state: 'completed')
                  .where(format: [1, 2]) # swiss, elimination
                  .where.not(championship_level: [nil, ''])

    if args[:year].present?
      year = args[:year].to_i
      Championship::Score.where(year: year).delete_all
      tournaments = tournaments.select { |t| (t.ends_at || t.updated_at).year == year }
      puts "Recalculating championship scores for year #{year}..."
    else
      Championship::Score.delete_all
      puts 'Recalculating championship scores for ALL years...'
    end

    puts "Found #{tournaments.size} eligible tournament(s)"

    tournaments.each do |tournament|
      year = (tournament.ends_at || tournament.updated_at).year
      print "  [#{year}] #{tournament.name}..."
      Championship::ScoreCalculator.new(tournament).call
      puts ' done'
    end

    total = Championship::Score.count
    puts "Finished. #{total} championship score record(s) total."
  end
end
