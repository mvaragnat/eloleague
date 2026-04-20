# frozen_string_literal: true

namespace :championship do
  desc 'Recalculate championship scores for a year (default: current). Usage: championship:recalculate[2026]'
  task :recalculate, [:year] => [:environment] do |_task, args|
    year = (args[:year] || Time.current.year).to_i
    puts "Recalculating championship scores for year #{year}..."

    Championship::Score.where(year: year).delete_all

    tournaments = Tournament::Tournament
                  .where(state: 'completed')
                  .where(format: [1, 2]) # swiss, elimination
    tournaments = tournaments.select { |t| (t.ends_at || t.updated_at).year == year }

    puts "Found #{tournaments.size} eligible tournament(s)"

    tournaments.each do |tournament|
      print "  Processing #{tournament.name}..."
      Championship::ScoreCalculator.new(tournament).call
      puts ' done'
    end

    total = Championship::Score.where(year: year).count
    puts "Finished. #{total} championship score record(s) created."
  end
end
