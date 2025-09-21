# frozen_string_literal: true

namespace :seed do
  task demo_users: :environment do
    20.times do |user_number|
      next if User.find_by(email: "user#{user_number}@test.com").present?

      User.create!(
        username: "user#{user_number}",
        email: "user#{user_number}@test.com",
        password: "password#{user_number}"
      )
    end
    Rails.logger.info '20 users created'
  end
end
