# frozen_string_literal: true

require 'caxlsx'

module Tournament
  # Builds an Excel (.xlsx) sheet listing every registration of a tournament:
  # username, email, registration status and whether the registration is confirmed.
  class MembersExport
    CONTENT_TYPE = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'

    def initialize(tournament:)
      @tournament = tournament
    end

    def filename
      "#{@tournament.name.parameterize.presence || 'tournament'}-members.xlsx"
    end

    def call
      package = Axlsx::Package.new
      package.workbook.add_worksheet(name: I18n.t('tournaments.members_export.sheet_name')) do |sheet|
        header = sheet.styles.add_style(b: true)
        sheet.add_row(header_row, style: header)
        registrations.each { |r| sheet.add_row(row_for(r), types: %i[string string string string]) }
      end
      package.to_stream.read
    end

    private

    def registrations
      @tournament.registrations.includes(:user).sort_by { |r| r.user.username.downcase }
    end

    def header_row
      %w[username email status confirmed].map { |key| I18n.t("tournaments.members_export.columns.#{key}") }
    end

    def row_for(registration)
      [
        registration.user.username,
        registration.user.email,
        I18n.t("tournaments.show.participant_status.#{registration.status}", default: registration.status.humanize),
        I18n.t(registration.confirmed? ? 'tournaments.members_export.yes' : 'tournaments.members_export.no')
      ]
    end
  end
end
