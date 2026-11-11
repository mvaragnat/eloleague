# frozen_string_literal: true

module ApplicationHelper
  # Height of a match box (bracket and round pairing grids).
  MATCH_BOX_HEIGHT = 104

  # Tooltip behind a displayed rating: R ± RD and how to read the uncertainty.
  def rating_tooltip(rating, deviation)
    t('elo.rating_tooltip', rating: rating, deviation: deviation, provisional: Elo::Calculator::PROVISIONAL_RD)
  end

  def game_event_error_flags(event)
    return {} unless event&.errors&.any?

    attrs = event.errors.attribute_names.map(&:to_sym)
    base_error = attrs.include?(:base)
    players_error = attrs.include?(:players)

    {
      system: attrs.include?(:game_system_id),
      scoring_system: attrs.include?(:scoring_system) || attrs.include?(:scoring_system_id),
      players: players_error || attrs.any? { |attr| attr.to_s.include?('user') },
      scores: players_error || base_error || attrs.any? { |attr| attr.to_s.include?('score') },
      factions: players_error || attrs.any? { |attr| attr.to_s.include?('faction') }
    }
  end

  # Renders an SVG bracket for elimination tournaments.
  # Uses parent/child relations; no fallback to rounds.
  def render_svg_bracket(tournament, _rounds)
    elim_matches = tournament.matches.where(tournament_round_id: nil)
    if elim_matches.none?
      return content_tag(:p, t('tournaments.show.no_rounds', default: 'No rounds yet'), class: 'card-date')
    end

    # Compute depth to root for each match
    depth_cache = {}
    compute_depth = lambda do |m|
      return depth_cache[m.id] if depth_cache.key?(m.id)

      d = 0
      cur = m
      while cur.parent_match
        d += 1
        cur = cur.parent_match
      end
      depth_cache[m.id] = d
    end
    elim_matches.each { |m| compute_depth.call(m) }

    max_depth = depth_cache.values.max || 0

    # Build levels with leaves at level 0, root at level max_depth
    levels = Array.new(max_depth + 1) { [] }
    elim_matches.includes(:a_user, :b_user, :child_matches, :parent_match).order(:created_at).each do |m|
      level = max_depth - depth_cache[m.id]
      levels[level] << m
    end

    # Layout constants
    cell_w = 240
    cell_h = MATCH_BOX_HEIGHT
    col_gap = 120
    row_gap = 36
    padding = 24
    elbow = 28

    # Compute x positions per level
    x_for_level = ->(lvl) { padding + (lvl * (cell_w + col_gap)) }

    # Compute y positions: leaves placed sequentially; parents centered between children
    positions = {}

    # Leaves
    leaves = levels[0]
    leaves.each_with_index do |m, idx|
      positions[m.id] = { x: x_for_level.call(0), y: padding + (idx * (cell_h + row_gap)) }
    end

    # Upper levels
    (1..max_depth).each do |lvl|
      levels[lvl].each do |m|
        kids = m.child_matches.order(:created_at).to_a
        centers = kids.map do |ch|
          pos = positions[ch.id]
          pos ? (pos[:y] + (cell_h / 2)) : nil
        end.compact

        center_y = if centers.any?
                     (centers.sum.to_f / centers.size)
                   else
                     # Fallback if children unknown: stack
                     padding + (levels[lvl].index(m) * (cell_h + row_gap))
                   end

        positions[m.id] = { x: x_for_level.call(lvl), y: (center_y - (cell_h / 2)).round }
      end
    end

    # Compute overall width/height from positions actually used
    col_count = levels.size
    # rubocop:disable Rails/Pluck
    max_y = positions.values.map { |p| p[:y] }.max || 0
    # rubocop:enable Rails/Pluck
    height = (max_y + cell_h + padding)
    width = padding + (col_count * cell_w) + ((col_count - 1) * col_gap)

    content_tag(:div, style: 'overflow-x:auto; -webkit-overflow-scrolling:touch;') do
      content_tag(:svg, width: width, height: height + 20, style: 'display:block;') do
        header_labels = levels.each_with_index.map do |_matches, c|
          x = x_for_level.call(c) + (cell_w / 2)
          content_tag(:text, round_label_for_column(c, col_count), x: x, y: padding - 6, 'text-anchor': 'middle',
                                                                   'font-size': 12, fill: '#6b7280')
        end

        # Elbow connectors
        elbows = elim_matches.flat_map do |m|
          from = positions[m.id]
          next [] unless from

          parent_center_y = from[:y] + (cell_h / 2)
          m.child_matches.map do |child|
            to = positions[child.id]
            next nil unless to

            child_center_y = to[:y] + (cell_h / 2)
            x1 = to[:x] + cell_w
            hx = from[:x] - elbow
            [
              content_tag(:line, nil, x1: x1, y1: child_center_y, x2: hx, y2: child_center_y, stroke: '#cbd5e1',
                                      'stroke-width': 2),
              content_tag(:line, nil, x1: hx, y1: child_center_y, x2: hx, y2: parent_center_y, stroke: '#cbd5e1',
                                      'stroke-width': 2),
              content_tag(:line, nil, x1: hx, y1: parent_center_y, x2: from[:x], y2: parent_center_y,
                                      stroke: '#cbd5e1', 'stroke-width': 2)
            ]
          end.compact
        end

        # Match boxes
        boxes = elim_matches.map do |m|
          pos = positions[m.id]
          next nil unless pos

          small_match_box(tournament, m, pos[:x], pos[:y], width: cell_w)
        end.compact

        safe_join([header_labels, elbows, boxes].flatten)
      end
    end
  end

  # Everything a view needs to display a match: both sides (name, faction, score,
  # outcome, army list link), the status of an unplayed match and the link to open it.
  def match_display(tournament, match)
    admin = Current.user && tournament.creator_id == Current.user.id
    a_set = match.a_user_id.present?
    b_set = match.b_user_id.present?
    leaf = match.child_matches.empty?
    bye_label = t('tournaments.show.bye', default: 'Bye')

    a = match_display_side(tournament, match.a_user, !a_set && b_set && leaf)
    b = match_display_side(tournament, match.b_user, a_set && !b_set && leaf)
    played = match.game_event_id.present?

    if played
      pa = match.game_event.game_participations.find_by(user: match.a_user)
      pb = match.game_event.game_participations.find_by(user: match.b_user)
      a[:faction] = pa.faction.localized_name(I18n.locale) if pa&.faction
      b[:faction] = pb.faction.localized_name(I18n.locale) if pb&.faction
      a[:score] = pa&.score
      b[:score] = pb&.score
      # Outcome follows the stored match.result, which reflects the scoring rules
      a[:outcome], b[:outcome] = { 'a_win' => %i[win loss], 'b_win' => %i[loss win],
                                   'draw' => %i[draw draw] }.fetch(match.result, [nil, nil])
      allowed = admin
    else
      one_sided_win = (a_set && !b_set && match.result == 'a_win') || (b_set && !a_set && match.result == 'b_win')
      status = one_sided_win ? bye_label : t('tournaments.show.pending', default: 'Pending')
      allowed = admin || [match.a_user_id, match.b_user_id].compact.include?(Current.user&.id)
    end

    {
      a: a, b: b, played: played, status: status,
      score_text: played ? "#{a[:score]} - #{b[:score]}" : status,
      link: allowed && a_set && b_set ? tournament_tournament_match_path(tournament, match) : nil,
      table: match.respond_to?(:table_number) ? match.table_number.presence : nil
    }
  end

  # Render a small match box (names, optional score, winner highlighted) as used in elimination bracket.
  def small_match_box(tournament, match, pos_x, pos_y, options = {})
    cell_w = options[:width].presence || 240
    cell_h = MATCH_BOX_HEIGHT
    display = match_display(tournament, match)
    box_styles = { win: 'font-weight:700; fill:#16a34a;', draw: 'font-weight:700; fill:#2563eb;' }

    a_label = truncate(display[:a][:name], length: 24)
    b_label = truncate(display[:b][:name], length: 24)
    a_style = box_styles.fetch(display[:a][:outcome], '')
    b_style = box_styles.fetch(display[:b][:outcome], '')
    a_faction = display[:a][:faction]
    b_faction = display[:b][:faction]
    a_list_path = display[:a][:list_path]
    b_list_path = display[:b][:list_path]
    score_text = display[:score_text]
    link = display[:link]

    table_text = display[:table]&.to_s
    text_start_x = pos_x + (table_text ? 40 : 14)

    parts = [
      content_tag(:rect, nil, x: pos_x, y: pos_y, width: cell_w, height: cell_h, rx: 10, ry: 10,
                              fill: '#ffffff', stroke: '#e5e7eb', 'stroke-width': 3),
      # Table number (left column), when available
      (if table_text
         [
           content_tag(:circle, nil, cx: pos_x + 20, cy: pos_y + (cell_h / 2) - 4, r: 12, fill: '#f3f4f6'),
           content_tag(:text, table_text, x: pos_x + 20, y: pos_y + (cell_h / 2), 'text-anchor': 'middle',
                                          'font-size': 12, 'font-weight': 'bold', fill: '#4b5563')
         ]
       end),
      # Score or Pending aligned to the top-right
      content_tag(:text, score_text, x: pos_x + cell_w - 14, y: pos_y + 22, 'text-anchor': 'end',
                                     'font-size': 14, fill: '#6b7280'),
      # Top player username
      content_tag(:text, a_label, x: text_start_x, y: pos_y + 24,
                                  style: a_style, 'font-size': 14),
      # Top player faction and army list link (smaller, grey)
      match_box_player_details(a_faction, a_list_path, text_start_x, pos_y + 42),
      # Bottom player username
      content_tag(:text, b_label, x: text_start_x, y: pos_y + 66,
                                  style: b_style, 'font-size': 14),
      # Bottom player faction and army list link (smaller, grey)
      match_box_player_details(b_faction, b_list_path, text_start_x, pos_y + 84)
    ].flatten.compact

    if link
      parts << content_tag(
        :a,
        content_tag(:text, t('tournaments.open'), x: pos_x + cell_w - 14, y: pos_y + cell_h - 8, 'text-anchor': 'end',
                                                  'font-size': 12, fill: '#2563eb'),
        href: link
      )
    end

    safe_join(parts)
  end

  # Controller-generated list item for the matches list (turbo stream prepend)
  def match_list_item(tournament, match)
    render 'tournaments/match_row', tournament: tournament, match: match
  end

  private

  # One side of a match: the player, or a placeholder (bye / not known yet).
  def match_display_side(tournament, user, bye)
    unless user
      return { name: bye ? t('tournaments.show.bye', default: 'Bye') : 'TBD', placeholder: true }
    end

    { name: user.username, user: user, faction: faction_label_for_user(tournament, user),
      list_path: army_list_path_for_user(tournament, user.id) }
  end

  def round_label_for_column(index, total)
    return 'Final' if index == total - 1
    return 'Semifinal' if index == total - 2
    return 'Quarterfinal' if index == total - 3

    "R#{index + 1}"
  end

  def build_seed_map_for(tournament)
    users = tournament.participants.to_a
    system = tournament.game_system
    seeded = users.map do |u|
      rating = EloRating.conservative_for(u, system)
      [u.id, rating]
    end
    seeded.sort_by! { |(_id, rating)| -rating }
    seeded.to_h { |uid, rating| [uid, seeded.index([uid, rating]) + 1] }
  end

  # Registrations of a tournament indexed by user id, memoized for the current
  # render (one query per tournament, however many match boxes are drawn).
  def registrations_by_user_for(tournament)
    @registrations_by_user ||= {}
    @registrations_by_user[tournament.id] ||= tournament.registrations.includes(:faction).index_by(&:user_id)
  end

  def faction_label_for_user(tournament, user)
    return nil unless user

    registrations_by_user_for(tournament)[user.id]&.faction&.localized_name(I18n.locale)
  end

  # Path to a player's army list, when it can be viewed (same rule as the
  # participants and standings tables: once the tournament has started).
  def army_list_path_for_user(tournament, user_id)
    return nil unless user_id && (tournament.running? || tournament.completed?)

    registration = registrations_by_user_for(tournament)[user_id]
    return nil if registration&.army_list.blank?

    tournament_tournament_registration_path(tournament, registration)
  end

  # Second line of a player in a match box: faction, then a link to the army list.
  def match_box_player_details(faction, list_path, pos_x, pos_y)
    return nil if faction.blank? && list_path.nil?

    content_tag(:text, x: pos_x, y: pos_y, 'font-size': 12, fill: '#6b7280') do
      parts = []
      parts << truncate(faction, length: list_path ? 15 : 24) if faction.present?
      parts << ' · ' if faction.present? && list_path
      if list_path
        parts << content_tag(:a, href: list_path, target: '_blank', rel: 'noopener') do
          content_tag(:tspan, t('tournaments.show.view_army_list', default: 'Army list'),
                      fill: '#2563eb', 'font-size': 11, 'text-decoration': 'underline')
        end
      end
      safe_join(parts)
    end
  end
end
