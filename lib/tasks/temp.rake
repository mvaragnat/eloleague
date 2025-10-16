# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
namespace :temp do
  desc 'Backdate tournament events to a target date and rebuild Elo. '
  task :backdate_tournament, %i[tournament_id date] => :environment do |_task, args|
    tournament_id = args[:tournament_id].to_s.strip
    date_str = args[:date].to_s.strip

    if tournament_id.blank? || date_str.blank?
      puts "ERROR: Provide tournament_id and date. Example: heroku run rails 'temp:backdate_tournament[135,2025-06-27]'"
      next
    end

    tournament = Tournament::Tournament.find(tournament_id)

    begin
      parsed = Time.zone.parse(date_str)
    rescue StandardError
      parsed = nil
    end

    if parsed.blank?
      puts "ERROR: Could not parse date '#{date_str}'. Expected format like 2025-06-27."
      next
    end

    new_time = Time.zone.local(parsed.year, parsed.month, parsed.day, 12, 0, 0)

    puts "Backdating events for Tournament ##{tournament.id} '#{tournament.name}' to #{new_time.to_date}..."

    events = Game::Event.where(tournament_id: tournament.id).includes(:tournament)
    if events.blank?
      puts 'No events found for this tournament. Nothing to do.'
      next
    end

    # insert a small offset to have consistent ELO ordering
    events.each_with_index do |event, i|
      event.update(played_at: new_time + i.minutes)
    end

    # then play elo rebuild
    Rake::Task['elo:rebuild'].reenable
    Rake::Task['elo:rebuild'].invoke(tournament.game_system_id)
  end

  # reset de la base le 03/09/25
  # EloChange.destroy_all
  # Tournament::Match.destroy_all
  # Game::Event.destroy_all

  desc 'Create 28 users and register them to tournament ID 5'
  task create_users_and_register: :environment do
    tournament = Tournament::Tournament.find(15)

    User.limit(10).each do |user|
      unless tournament.registrations.exists?(user: user)
        Tournament::Registration.create!(
          tournament: tournament,
          user: user,
          status: 'pending'
        )
      end

      puts "Registered #{user.username} to tournament #{tournament.name}"
    end

    tournament.reload.registrations.find_each { |participation| participation.update(status: 'checked_in') }
  end

  desc 'Populate slugs for existing tournaments without slugs'
  task populate_tournament_slugs: :environment do
    tournaments_without_slugs = Tournament::Tournament.where(slug: nil)
    count = tournaments_without_slugs.count

    if count.zero?
      puts 'All tournaments already have slugs. Nothing to do.'
      return
    end

    puts "Found #{count} tournament(s) without slugs. Processing..."

    tournaments_without_slugs.find_each do |tournament|
      base_slug = tournament.name.to_s
                            .unicode_normalize(:nfd)
                            .gsub(/[\u0300-\u036f]/, '') # Remove accents
                            .downcase
                            .gsub(/[^a-z0-9\s-]/, '') # Remove special characters (keep spaces & hyphens)
                            .gsub(/[-\s]+/, '_') # Replace spaces and hyphens with underscores
                            .gsub(/_+/, '_') # Remove multiple underscores
                            .gsub(/^_|_$/, '') # Remove leading/trailing underscores

      # Ensure uniqueness by appending tournament ID if slug already exists
      slug = base_slug.presence || "tournament_#{tournament.id}"
      slug = "#{slug}_#{tournament.id}" if Tournament::Tournament.where(slug: slug).where.not(id: tournament.id).exists?

      # rubocop:disable Rails/SkipsModelValidations
      tournament.update_column(:slug, slug) # Intentionally skip validations to avoid triggering callbacks
      # rubocop:enable Rails/SkipsModelValidations
      puts "  ✓ Tournament ##{tournament.id} '#{tournament.name}' → slug: '#{slug}'"
    end

    puts "\nSuccessfully populated slugs for #{count} tournament(s)."
  end
end
# rubocop:enable Metrics/BlockLength
