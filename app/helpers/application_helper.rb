# frozen_string_literal: true

module ApplicationHelper
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
    cell_h = 88
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

  # Render a small match box (names, optional score, winner highlighted) as used in elimination bracket.
  # Exposed to reuse in other formats (e.g., swiss/open rounds list) by calling this helper per match.
  def small_match_box(tournament, match, pos_x, pos_y, options = {})
    cell_w = options[:width].presence || 240
    cell_h = 88
    admin = Current.user && tournament.creator_id == Current.user.id

    a_set = match.a_user_id.present?
    b_set = match.b_user_id.present?
    a_bye = !a_set && b_set && match.child_matches.empty?
    b_bye = a_set && !b_set && match.child_matches.empty?

    a_name = if a_set
               match.a_user.username
             elsif a_bye
               t('tournaments.show.bye', default: 'Bye')
             else
               'TBD'
             end
    b_name = if b_set
               match.b_user.username
             elsif b_bye
               t('tournaments.show.bye', default: 'Bye')
             else
               'TBD'
             end

    a_faction = match.a_user_id ? faction_label_for_user(tournament, match.a_user) : nil
    b_faction = match.b_user_id ? faction_label_for_user(tournament, match.b_user) : nil

    a_label = truncate(a_name, length: 24)
    b_label = truncate(b_name, length: 24)
    a_faction_label = a_faction.present? ? truncate(a_faction, length: 24) : nil
    b_faction_label = b_faction.present? ? truncate(b_faction, length: 24) : nil

    if match.game_event_id
      pa = match.game_event.game_participations.find_by(user: match.a_user)
      pb = match.game_event.game_participations.find_by(user: match.b_user)
      a_style = pa&.score.to_i > pb&.score.to_i ? 'font-weight:700; fill:#16a34a;' : ''
      b_style = pb&.score.to_i > pa&.score.to_i ? 'font-weight:700; fill:#16a34a;' : ''
      score_text = "#{pa&.score} - #{pb&.score}"
      # For open format listing, we may show secondary below or omit to reduce clutter. Keep compact here.
      both_present = match.a_user_id.present? && match.b_user_id.present?
      link = admin && both_present ? tournament_tournament_match_path(tournament, match) : nil
    else
      a_style = ''
      b_style = ''
      # If one-sided bye win, show BYE rather than Pending
      score_text = if (match.a_user_id && match.b_user_id.nil? && match.result == 'a_win') ||
                      (match.b_user_id && match.a_user_id.nil? && match.result == 'b_win')
                     t('tournaments.show.bye', default: 'Bye')
                   else
                     t('tournaments.show.pending', default: 'Pending')
                   end
      both_present = match.a_user_id.present? && match.b_user_id.present?
      allowed = both_present && (admin || [match.a_user_id, match.b_user_id].compact.include?(Current.user&.id))
      link = allowed ? tournament_tournament_match_path(tournament, match) : nil
    end

    parts = [
      content_tag(:rect, nil, x: pos_x, y: pos_y, width: cell_w, height: cell_h, rx: 10, ry: 10,
                              fill: '#ffffff', stroke: '#e5e7eb', 'stroke-width': 3),
      # Score or Pending aligned to the top-right
      content_tag(:text, score_text, x: pos_x + cell_w - 14, y: pos_y + 22, 'text-anchor': 'end',
                                     'font-size': 14, fill: '#6b7280'),
      # Top player username
      content_tag(:text, a_label, x: pos_x + 14, y: pos_y + 26,
                                  style: a_style, 'font-size': 14),
      # Top player faction (smaller, grey)
      (if a_faction_label
         content_tag(:text, a_faction_label, x: pos_x + 14, y: pos_y + 42,
                                             'font-size': 12, fill: '#6b7280')
       end),
      # Bottom player username
      content_tag(:text, b_label, x: pos_x + 14, y: pos_y + 64,
                                  style: b_style, 'font-size': 14),
      # Bottom player faction (smaller, grey)
      (if b_faction_label
         content_tag(:text, b_faction_label, x: pos_x + 14, y: pos_y + 80,
                                             'font-size': 12, fill: '#6b7280')
       end)
    ].compact

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

  # Controller-generated list item wrapper for small match boxes
  def svg_match_list_item(tournament, match)
    content_tag(:li, style: 'margin:0; display:flex; justify-content:center;') do
      content_tag(:svg, width: 240, height: 88) do
        small_match_box(tournament, match, 0, 0, width: 240, show_seeds: false)
      end
    end
  end

  private

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
      rating = EloRating.find_by(user: u, game_system: system)&.rating || EloRating::START_RATING
      [u.id, rating]
    end
    seeded.sort_by! { |(_id, rating)| -rating }
    seeded.to_h { |uid, rating| [uid, seeded.index([uid, rating]) + 1] }
  end

  def registration_faction_map_for(tournament)
    registration_cache = Thread.current[:registration_faction_map_cache] ||= {}
    registration_cache[tournament.id] ||= tournament.registrations
                                                    .includes(:faction)
                                                    .each_with_object({}) do |reg, acc|
      acc[reg.user_id] = reg.faction&.localized_name(I18n.locale)
    end
    registration_cache[tournament.id]
  end

  def faction_label_for_user(tournament, user)
    return nil unless user

    registration_faction_map_for(tournament)[user.id]
  end
end
