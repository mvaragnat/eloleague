# frozen_string_literal: true

class ContactsController < ApplicationController
  def new
    @contact = Contact.new
  end

  def create
    @contact = Contact.new(contact_params)
    @contact.username = current_user.username

    if @contact.valid?
      ContactMailer.notify(
        subject: @contact.subject,
        content: @contact.content,
        from: @contact.username,
        from_email: current_user.email
      ).deliver_now
      redirect_to root_path, notice: t('contact.create.success')
    else
      flash.now[:alert] = t('contact.create.failure')
      render :new, status: :unprocessable_entity
    end
  end

  private

  def contact_params
    params.expect(contact: %i[subject content])
  end
end
