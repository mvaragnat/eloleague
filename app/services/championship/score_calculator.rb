# frozen_string_literal: true

module Championship
  class ScoreCalculator
    MATCH_POINTS = {
      win: 3,
      draw: 2,
      loss: 1

      # version anglaise
      # win: 0, 
      # draw: 0, 
      # loss: 0,
    }.freeze

    PLACEMENT_BONUS = {
      # ma proposition
      1 => 3,
      2 => 2,
      3 => 1

      # version anglaise
      # 1 => 10,
      # 2 => 8,
      # 3 => 6,
      # 4 => 4,
      # 5 => 2
    }.freeze

    ELIGIBLE_FORMATS = %w[swiss elimination].freeze

    def initialize(tournament)
      @tournament = tournament
    end

    def call
      return unless eligible?

      year = championship_year
      standings = ::Tournament::Standings.new(@tournament).rows
      user_match_points = compute_match_points
      user_placement_bonus = compute_placement_bonus(standings)

      all_user_ids = (user_match_points.keys + user_placement_bonus.keys).uniq

      all_user_ids.each do |user_id|
        mp = user_match_points.fetch(user_id, 0)
        pb = user_placement_bonus.fetch(user_id, 0)

        Championship::Score.find_or_initialize_by(
          user_id: user_id,
          tournament_id: @tournament.id
        ).update!(
          game_system_id: @tournament.game_system_id,
          year: year,
          match_points: mp,
          placement_bonus: pb,
          total_points: mp + pb
        )
      end
    end

    private

    def eligible?
      @tournament.completed? && ELIGIBLE_FORMATS.include?(@tournament.format)
    end

    def championship_year
      (@tournament.ends_at || @tournament.updated_at).year
    end

    def compute_match_points
      points = Hash.new(0)

      @tournament.matches.includes(:a_user, :b_user).find_each do |match|
        next if match.result == 'pending'
        next unless match.a_user && match.b_user

        case match.result
        when 'a_win'
          points[match.a_user_id] += MATCH_POINTS[:win]
          points[match.b_user_id] += MATCH_POINTS[:loss]
        when 'b_win'
          points[match.a_user_id] += MATCH_POINTS[:loss]
          points[match.b_user_id] += MATCH_POINTS[:win]
        when 'draw'
          points[match.a_user_id] += MATCH_POINTS[:draw]
          points[match.b_user_id] += MATCH_POINTS[:draw]
        end
      end

      points
    end

    def compute_placement_bonus(standings)
      bonus = {}

      standings.first(3).each_with_index do |row, index|
        placement = index + 1
        bonus[row.user.id] = PLACEMENT_BONUS.fetch(placement, 0)
      end

      bonus
    end
  end
end
