# frozen_string_literal: true

class ContactMailer < ApplicationMailer
  def notify(subject:, content:, from:)
    @content = content

    mail(
      to: ENV.fetch('CONTACT_TO_EMAIL', nil),
      from: ENV.fetch('GMAIL_USERNAME', nil),
      subject: "[Eloleague] #{subject} de #{from}"
    )
  end
end
