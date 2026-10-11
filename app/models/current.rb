# frozen_string_literal: true

class Current < ActiveSupport::CurrentAttributes
  attribute :user
  attribute :admin
  attribute :game_site
  attribute :game_system
end
