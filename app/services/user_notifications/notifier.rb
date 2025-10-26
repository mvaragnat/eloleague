# frozen_string_literal: true

module UserNotifications
  class Notifier
    class << self
      def game_event_created(event)
        # Do not notify here for tournament-linked events to avoid duplicate with match-result email
        return if event.tournament_id.present?

        actor = Current.user
        recipients = event.players.to_a
        recipients = filter_out_actor(recipients, actor)

        by_username = actor&.username
        recipients.each do |user|
          UserNotificationMailer
            .with(event: event, user: user, by_username: by_username)
            .game_event_recorded
            .deliver_later
        end
      end

      def match_created(match)
        # Notify only for Swiss/Open round-generated matches (round present). Skip open tournament ad-hoc matches.
        return if match.round.blank?

        [match.a_user, match.b_user].compact.each do |user|
          UserNotificationMailer
            .with(match: match, user: user)
            .tournament_match_created
            .deliver_later
        end
      end

      def match_result_recorded(match, event)
        actor = Current.user
        recipients = [match.a_user, match.b_user].compact
        recipients = filter_out_actor(recipients, actor)
        by_username = actor&.username

        recipients.each do |user|
          UserNotificationMailer
            .with(match: match, event: event, user: user, by_username: by_username)
            .tournament_match_result_recorded
            .deliver_later
        end
      end

      def tournament_completed(tournament, top3_usernames)
        tournament.participants.find_each do |user|
          UserNotificationMailer
            .with(tournament: tournament, user: user, top3: top3_usernames)
            .tournament_completed
            .deliver_later
        end
      end

      private

      def filter_out_actor(users, actor)
        return users if actor.nil?

        users.reject { |u| u.id == actor.id }
      end
    end
  end
end
