# frozen_string_literal: true

module Tournament
  module StrategyRegistry
    module_function

    # Pairing strategies map: key => [human_label, class]
    def pairing_strategies
      {
        'by_points_random_within_group' => ['By Points (random within ties)', ::Tournament::Pairing::ByPointsRandomWithinGroup]
      }
    end

    # Tie-break strategies map for standings (applied in order): key => [human_label, lambda]
    # The lambda receives (user_id, aggregator_hash) and returns a numeric tie-break value.
    def tiebreak_strategies
      {
        'none' => ['None', ->(_uid, _agg) { 0.0 }],
        'score_sum' => ['Score sum', ->(uid, agg) { agg[:score_sum_by_user_id][uid] || 0.0 }],
        'secondary_score_sum' => ['Secondary score sum', lambda { |uid, agg|
          agg[:secondary_score_sum_by_user_id][uid] || 0.0
        }],
        'sos' => ['Strength of Schedule', lambda { |uid, agg|
          (agg[:opponents_by_user_id][uid] || []).sum { |oid| agg[:points_by_user_id][oid] || 0.0 }
        }]
      }
    end

    # Primary strategies map for standings (first sorting criterion): key => [human_label, lambda]
    # Reuses the same building blocks as tie-breakers with an added 'points' option.
    def primary_strategies
      tiebreak_strategies.merge(
        'points' => ['Points', ->(uid, agg) { agg[:points_by_user_id][uid] || 0.0 }]
      )
    end

    def default_pairing_key
      'by_points_random_within_group'
    end

    def default_tiebreak1_key
      'score_sum'
    end

    def default_tiebreak2_key
      'none'
    end

    def default_primary_key
      'points'
    end
  end
end
