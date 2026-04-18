# frozen_string_literal: true

module Api
  class ChampionshipsController < BaseController
    def rankings
      game_system = Game::System.find_by(id: params[:game_system_id])
      return render json: { error: 'game_system not found' }, status: :not_found unless game_system

      year = params[:year].to_i

      scores = Championship::Score
               .for_game_system(game_system)
               .for_year(year)
               .includes(:user)

      standings = build_standings(scores)

      render json: {
        game_system: game_system.name,
        year: year,
        rankings: standings.map do |s|
          {
            rank: s[:rank],
            username: s[:user].username,
            total_points: s[:total_points],
            match_points: s[:match_points],
            placement_bonus: s[:placement_bonus],
            tournaments_count: s[:tournaments_count]
          }
        end
      }
    end

    private

    def build_standings(scores)
      grouped = scores.group_by(&:user)

      standings = grouped.map do |user, user_scores|
        {
          user: user,
          total_points: user_scores.sum(&:total_points),
          match_points: user_scores.sum(&:match_points),
          placement_bonus: user_scores.sum(&:placement_bonus),
          tournaments_count: user_scores.size
        }
      end

      standings.sort_by! { |s| [-s[:total_points], s[:user].username] }

      rank = 1
      previous_score = nil
      previous_rank = nil

      standings.each do |standing|
        standing[:rank] = if previous_score && previous_rank && standing[:total_points] == previous_score
                            previous_rank
                          else
                            rank
                          end
        previous_rank = standing[:rank]
        previous_score = standing[:total_points]
        rank += 1
      end

      standings
    end
  end
end
