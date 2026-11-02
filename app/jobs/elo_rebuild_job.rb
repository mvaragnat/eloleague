# frozen_string_literal: true

# Recomputes a game system's ratings, e.g. after a reported game becomes (non-)competitive.
class EloRebuildJob < ApplicationJob
  queue_as :default

  def perform(game_system_id)
    Elo::Rebuilder.new(game_system_id: game_system_id).call
  end
end
