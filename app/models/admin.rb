# frozen_string_literal: true

class Admin < ApplicationRecord
  # Devise for authentication: login/logout only
  devise :database_authenticatable, :rememberable, :validatable
end
