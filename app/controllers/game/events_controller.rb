# frozen_string_literal: true

module Game
  class EventsController < ApplicationController
    before_action :authenticate_user!
    def new
      @game = Event.new
      @game.game_participations.build(user: Current.user)
    end

    def create
      @game = Event.new(game_params.merge(played_at: Time.current))

      respond_to do |format|
        @game.save ? respond_with_create_success(format) : respond_with_create_failure(format)
      end
    end

    private

    # rubocop:disable Rails/StrongParametersExpect
    def game_params
      key = params.key?(:event) ? :event : :game_event
      params.require(key).permit(
        :game_system_id,
        game_participations_attributes: %i[user_id score secondary_score faction_id army_list]
      )
    end
    # rubocop:enable Rails/StrongParametersExpect

    def render_component_html
      view_context.render(
        GameEventComponent.new(event: @game, current_user: Current.user)
      )
    end

    def respond_with_create_success(format)
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove('no-games-message'),
          turbo_stream.prepend('games-list', render_component_html),
          turbo_stream.replace('modal', '')
        ]
      end
      format.html { redirect_to dashboard_path, notice: t('.success') }
    end

    def respond_with_create_failure(format)
      format.turbo_stream { render :new, status: :unprocessable_content }
      format.html { render :new, status: :unprocessable_content }
    end
  end
end
