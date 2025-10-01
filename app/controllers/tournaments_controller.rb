# frozen_string_literal: true

class TournamentsController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index show]
  before_action :set_tournament,
                only: %i[show register unregister check_in lock_registration finalize next_round update]
  before_action :authorize_admin!, only: %i[lock_registration finalize next_round update]

  def index
    # Populate Current.session/user even when authentication is not required
    # Populate Current.user for guest pages
    Current.user = current_user

    scope = ::Tournament::Tournament.includes(:game_system, :creator).order(created_at: :desc)
    @my_tournaments = Current.user ? scope.where(creator: Current.user) : scope.none
    @accepting_tournaments = scope.where(state: %w[draft registration])
    @ongoing_tournaments = scope.where(state: 'running')
    @closed_tournaments = scope.where(state: 'completed')
  end

  def show
    # Populate Current.session/user for guest-access pages
    Current.user = current_user

    @rounds = @tournament.rounds.includes(matches: %i[a_user b_user]).order(:number)
    @registrations = @tournament.registrations.includes(:user)
    @matches = @tournament.matches.order(created_at: :desc).limit(20)
    @active_tab_index = (params[:tab].presence || 0).to_i
    @is_registered = Current.user && @tournament.registrations.exists?(user_id: Current.user.id)
    @my_registration = Current.user && @tournament.registrations.find_by(user_id: Current.user.id)

    # Expose strategies for Admin dropdowns
    @pairing_strategies = Tournament::StrategyRegistry.pairing_strategies
    @tiebreak_strategies = Tournament::StrategyRegistry.tiebreak_strategies
    @primary_strategies = Tournament::StrategyRegistry.primary_strategies

    standings_data = compute_standings_with_tiebreaks(@tournament)
    @standings = standings_data[:rows]
    @primary_label = standings_data[:primary_label]
    @tiebreak1_label = standings_data[:tiebreak1_label]
    @tiebreak2_label = standings_data[:tiebreak2_label]

    last_round = @rounds.last
    if last_round
      any_pending = last_round.matches.any? { |m| m.result == 'pending' }
      @can_move_to_next_round = !any_pending
      @move_block_reason = if any_pending
                             t('tournaments.cannot_advance_pending',
                               default: 'All matches must be completed to move to the next round')
                           end
    else
      # No rounds yet; allow starting the first round if running
      @can_move_to_next_round = @tournament.running?
      @move_block_reason = nil
    end
  end

  def new
    @tournament = ::Tournament::Tournament.new
  end

  def create
    @tournament = ::Tournament::Tournament.new(tournament_params)
    @tournament.creator = Current.user

    if @tournament.save
      redirect_to tournament_path(@tournament), notice: t('tournaments.created', default: 'Tournament created')
    else
      render :new, status: :unprocessable_content
    end
  end

  def register
    unless can_register?
      return redirect_back(
        fallback_location: tournament_path(@tournament),
        alert: t('tournaments.closed', default: 'Registration closed')
      )
    end

    if @tournament.registration_full?
      return redirect_back(
        fallback_location: tournament_path(@tournament),
        alert: t('tournaments.full', default: 'Tournament is full')
      )
    end

    @tournament.registrations.find_or_create_by!(user: Current.user)
    # Participants tab index shifts by +1 due to new Overview tab
    redirect_to tournament_path(@tournament, tab: 2),
                notice: t('tournaments.registered', default: 'Registered')
  end

  def unregister
    unless can_register?
      return redirect_back(
        fallback_location: tournament_path(@tournament),
        alert: t('tournaments.closed', default: 'Registration closed')
      )
    end

    @tournament.registrations.where(user: Current.user).destroy_all
    redirect_to tournament_path(@tournament), notice: t('tournaments.unregistered', default: 'Unregistered')
  end

  def check_in
    unless can_register?
      return redirect_back(
        fallback_location: tournament_path(@tournament),
        alert: t('tournaments.closed', default: 'Registration closed')
      )
    end

    reg = @tournament.registrations.find_by!(user: Current.user)
    if reg.faction_id.blank?
      return redirect_back(
        fallback_location: tournament_path(@tournament, tab: 2),
        alert: t('tournaments.faction_required_to_check_in', default: 'Please select your faction before checking in')
      )
    end

    if @tournament.require_army_list_for_check_in && reg.army_list.blank?
      return redirect_back(
        fallback_location: tournament_path(@tournament, tab: 2),
        alert: t('tournaments.army_list_required_to_check_in',
                 default: 'Please provide your army list before checking in')
      )
    end

    reg.update!(status: 'checked_in')
    redirect_to tournament_path(@tournament), notice: t('tournaments.checked_in', default: 'Checked in')
  end

  # Admin
  def lock_registration
    unless can_register?
      return redirect_back(
        fallback_location: tournament_path(@tournament),
        alert: t('tournaments.not_allowed_state', default: 'Not allowed in current state')
      )
    end

    ApplicationRecord.transaction do
      @tournament.update!(state: 'running')
      @tournament.reload
      Tournament::BracketBuilder.new(@tournament).call if @tournament.elimination?
    end

    redirect_to tournament_path(@tournament), notice: t('tournaments.locked', default: 'Registration locked')
  end

  def next_round
    if @tournament.elimination?
      return redirect_back(
        fallback_location: tournament_path(@tournament),
        alert: t('tournaments.not_allowed_state', default: 'Not allowed in current state')
      )
    end

    unless @tournament.running?
      return redirect_back(
        fallback_location: tournament_path(@tournament),
        alert: t('tournaments.not_allowed_state', default: 'Not allowed in current state')
      )
    end

    last_round = @tournament.rounds.order(:number).last
    if last_round
      if last_round.matches.any? { |m| m.result == 'pending' }
        return redirect_back(
          fallback_location: tournament_path(@tournament),
          alert: t('tournaments.cannot_advance_pending',
                   default: 'All matches must be completed to move to the next round')
        )
      end
      last_round.update!(state: 'closed') unless last_round.state == 'closed'
    end

    # Create next round
    next_number = (last_round&.number || 0) + 1
    new_round = @tournament.rounds.create!(number: next_number, state: 'pending')

    # Generate pairings via registry strategy
    pairing_cls = Tournament::StrategyRegistry.pairing_strategies[@tournament.pairing_key].last
    result = pairing_cls.new(@tournament).call
    pairs = result.pairs
    pairs.each do |a_user, b_user|
      @tournament.matches.create!(round: new_round, a_user: a_user, b_user: b_user)
    end

    # If a bye is selected, record it as an immediate win for that player
    if result.respond_to?(:bye_user) && result.bye_user
      @tournament.matches.create!(round: new_round, a_user: result.bye_user, b_user: nil, result: 'a_win')
    end

    redirect_to tournament_path(@tournament, tab: 1),
                notice: t('tournaments.round_advanced', default: 'Moved to next round')
  end

  def finalize
    unless @tournament.running?
      return redirect_back(
        fallback_location: tournament_path(@tournament),
        alert: t('tournaments.not_allowed_state', default: 'Not allowed in current state')
      )
    end

    @tournament.update!(state: 'completed')
    redirect_to tournament_path(@tournament), notice: t('tournaments.finalized', default: 'Tournament finalized')
  end

  def update
    admin_tab_index = @tournament.elimination? ? 3 : 4
    if @tournament.update(tournament_params)
      respond_to do |format|
        format.html do
          redirect_to tournament_path(@tournament, tab: admin_tab_index),
                      notice: t('tournaments.updated', default: 'Tournament updated')
        end
        format.json { render json: { ok: true, message: t('tournaments.updated', default: 'Tournament updated') } }
      end
    else
      respond_to do |format|
        format.html do
          redirect_to tournament_path(@tournament, tab: admin_tab_index),
                      alert: @tournament.errors.full_messages.join(', ')
        end
        format.json do
          render json: { ok: false, errors: @tournament.errors.full_messages }, status: :unprocessable_content
        end
      end
    end
  end

  private

  def authenticate!
    redirect_to new_user_session_path unless Current.user
  end

  def set_tournament
    @tournament = ::Tournament::Tournament.find(params[:id])
  end

  def authorize_admin!
    return if Current.user && @tournament.creator_id == Current.user.id

    redirect_back(
      fallback_location: tournament_path(@tournament),
      alert: t('tournaments.unauthorized', default: 'Not authorized')
    )
  end

  def tournament_params
    params.require(:tournament).permit(
      :name,
      :description,
      :game_system_id,
      :format,
      :rounds_count,
      :starts_at,
      :ends_at,
      :pairing_strategy_key,
      :primary_strategy_key,
      :tiebreak1_strategy_key,
      :tiebreak2_strategy_key,
      :require_army_list_for_check_in,
      :non_competitive,
      :location,
      :online,
      :max_players,
      :score_for_bye
    )
  end

  def can_register?
    @tournament.state.in?(%w[draft registration])
  end

  # Returns rows with primary, points and tiebreak columns and labels
  def compute_standings_with_tiebreaks(tournament)
    points = Hash.new(0.0)
    score_sum = Hash.new(0.0)
    secondary_score_sum = Hash.new(0.0)
    opponents = Hash.new { |h, k| h[k] = [] }

    users = tournament.registrations.includes(:user).map(&:user)
    users.each do |u|
      points[u.id] ||= 0.0
      score_sum[u.id] ||= 0.0
      opponents[u.id] ||= []
    end

    aggregate_points_and_scores(tournament, points, score_sum, secondary_score_sum, opponents)

    agg = {
      score_sum_by_user_id: score_sum,
      secondary_score_sum_by_user_id: secondary_score_sum,
      points_by_user_id: points,
      opponents_by_user_id: opponents
    }

    tiebreaks = Tournament::StrategyRegistry.tiebreak_strategies
    primaries = Tournament::StrategyRegistry.primary_strategies
    # Be tolerant to legacy/invalid keys by falling back to defaults
    t1 = tiebreaks[tournament.tiebreak1_key] || tiebreaks[Tournament::StrategyRegistry.default_tiebreak1_key]
    t2 = tiebreaks[tournament.tiebreak2_key] || tiebreaks[Tournament::StrategyRegistry.default_tiebreak2_key]
    p1 = primaries[tournament.primary_key] || primaries[Tournament::StrategyRegistry.default_primary_key]

    # Helper lambdas for fixed displayed metrics
    sos_lambda = tiebreaks['sos'].last

    rows = users.map do |u|
      {
        user: u,
        points: points[u.id],
        score_sum: score_sum[u.id],
        secondary_score_sum: secondary_score_sum[u.id],
        sos: sos_lambda.call(u.id, agg),
        primary: p1.last.call(u.id, agg),
        tiebreak1: t1.last.call(u.id, agg),
        tiebreak2: t2.last.call(u.id, agg)
      }
    end

    rows.sort_by! { |h| [-h[:primary], -h[:tiebreak1], -h[:tiebreak2], h[:user].username] }

    primary_label = t("tournaments.show.strategies.names.primary.#{tournament.primary_key}", default: p1.first)
    t1_label = t("tournaments.show.strategies.names.tiebreak.#{tournament.tiebreak1_key}", default: t1.first)
    t2_label = t("tournaments.show.strategies.names.tiebreak.#{tournament.tiebreak2_key}", default: t2.first)
    { rows: rows, primary_label: primary_label, tiebreak1_label: t1_label, tiebreak2_label: t2_label }
  end

  def aggregate_points_and_scores(tournament, points, score_sum, secondary_score_sum, opponents)
    tournament.matches.includes(:a_user, :b_user, :game_event).find_each do |m|
      if bye_win_for_single_participant?(m)
        apply_bye_points(points, m)
        apply_bye_score(score_sum, m, tournament)
        next
      end

      next unless m.a_user && m.b_user

      # Track opponents for SoS
      opponents[m.a_user.id] << m.b_user.id
      opponents[m.b_user.id] << m.a_user.id

      apply_normal_result_points(points, m)

      a_score, b_score, a_secondary, b_secondary = extract_scores(m)
      next unless a_score && b_score

      score_sum[m.a_user.id] += a_score
      score_sum[m.b_user.id] += b_score

      secondary_score_sum[m.a_user.id] += a_secondary || 0.0
      secondary_score_sum[m.b_user.id] += b_secondary || 0.0
    end
  end

  def bye_win_for_single_participant?(match)
    (match.result == 'a_win' && match.a_user && match.b_user.nil?) ||
      (match.result == 'b_win' && match.b_user && match.a_user.nil?)
  end

  def apply_bye_points(points, match)
    if match.result == 'a_win' && match.a_user && match.b_user.nil?
      points[match.a_user.id] += 1.0
    elsif match.result == 'b_win' && match.b_user && match.a_user.nil?
      points[match.b_user.id] += 1.0
    end
  end

  def apply_bye_score(score_sum, match, tournament)
    bye_score = tournament.score_for_bye || 0
    if match.result == 'a_win' && match.a_user && match.b_user.nil?
      score_sum[match.a_user.id] += bye_score
    elsif match.result == 'b_win' && match.b_user && match.a_user.nil?
      score_sum[match.b_user.id] += bye_score
    end
  end

  def apply_normal_result_points(points, match)
    case match.result
    when 'a_win'
      points[match.a_user.id] += 1.0
    when 'b_win'
      points[match.b_user.id] += 1.0
    when 'draw'
      points[match.a_user.id] += 0.5
      points[match.b_user.id] += 0.5
    end
  end

  def extract_scores(match)
    return [nil, nil, nil, nil] unless match.game_event

    a_part = match.game_event.game_participations.find_by(user: match.a_user)
    b_part = match.game_event.game_participations.find_by(user: match.b_user)
    [a_part&.score.to_f, b_part&.score.to_f, a_part&.secondary_score.to_f, b_part&.secondary_score.to_f]
  end
end
