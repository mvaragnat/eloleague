# frozen_string_literal: true

class EloController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    @systems = load_systems
    @system = selected_system(@systems)
    @events = load_events(@system)
    @elo_changes_map = load_elo_changes(@events)

    @standings = compute_standings(@system)
  end

  private

  def load_systems
    Game::System.all.sort_by(&:localized_name)
  end

  def selected_system(systems)
    return systems.first if params[:game_system_id].blank?

    Game::System.find(params[:game_system_id])
  end

  def load_events(system)
    return Game::Event.none unless system

    Game::Event.where(game_system: system)
               .includes(:game_system, :game_participations, :players)
               .order(played_at: :desc)
  end

  def load_elo_changes(events)
    return {} if events.blank?

    changes = EloChange.where(game_event_id: events.map(&:id))
    changes.index_by { |ec| [ec.game_event_id, ec.user_id] }
  end

  def compute_standings(system)
    return [] unless system

    scope = ratings_scope(system)
    combined = combine_top_and_neighbors(scope)
    with_ranks(scope, combined)
  end

  def ratings_scope(system)
    # Deterministic order within ties by user_id
    EloRating.where(game_system: system).includes(:user).order(rating: :desc, user_id: :asc)
  end

  def combine_top_and_neighbors(scope)
    top10 = first_ten(scope)
    user = current_user_row(scope)

    return top10 + next_five(scope) unless user
    return top10 + next_five(scope) if user_rank(scope, user) <= 15

    top10 + neighbor_cluster(scope, user)
  end

  def first_ten(scope)
    scope.limit(10).to_a
  end

  def next_five(scope)
    scope.offset(10).limit(5).to_a
  end

  def current_user_row(scope)
    return nil unless Current.user

    scope.find_by(user: Current.user)
  end

  def user_rank(scope, user_row)
    higher = scope.where('rating > ?', user_row.rating).count
    higher + 1
  end

  def neighbor_cluster(scope, user_row)
    higher = scope.where('rating > ?', user_row.rating).count
    tie_before = scope.where('rating = ? AND user_id < ?', user_row.rating, user_row.user_id).count
    pos = higher + tie_before
    total = scope.count

    neighbors = []
    neighbors << :separator
    neighbors << scope.offset(pos - 1).limit(1).first if pos >= 1
    neighbors << user_row
    neighbors << scope.offset(pos + 1).limit(1).first if (pos + 1) < total
    neighbors << :separator
    neighbors
  end

  def with_ranks(scope, rows)
    rows.map do |row|
      if row == :separator
        { separator: true }
      else
        { rank: scope.where('rating > ?', row.rating).count + 1, row: row }
      end
    end
  end
end
