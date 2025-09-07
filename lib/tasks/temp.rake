# frozen_string_literal: true

namespace :temp do
  # reset de la base le 03/09/25
  # EloChange.destroy_all
  # Tournament::Match.destroy_all
  # Game::Event.destroy_all

  desc 'Create 28 users and register them to tournament ID 5'
  task create_users_and_register: :environment do
    tournament = Tournament::Tournament.find(15)

    User.limit(10).each do |user|
      Tournament::Registration.create!(
        tournament: tournament,
        user: user,
        status: 'pending'
      ) unless tournament.registrations.where(user: user).exists?

      puts "Registered #{user.username} to tournament #{tournament.name}"
    end

    tournament.reload.registrations.find_each { |participation| participation.update(status: 'checked_in') }
  end
end
