# frozen_string_literal: true

require 'test_helper'

class ContactsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:player_one)
    sign_in @user
  end

  test 'should get new' do
    get new_contact_path(locale: I18n.default_locale)
    assert_response :success
  end

  test 'should post create and redirect with notice' do
    received_notify_args = nil
    mail = Struct.new(:delivered) do
      def deliver_now
        self.delivered = true
      end
    end.new(false)

    ContactMailer.stub :notify, lambda { |**kwargs|
      received_notify_args = kwargs
      mail
    } do
      post contacts_path(locale: I18n.default_locale), params: { contact: { subject: 'Hello', content: 'World' } }
    end

    assert mail.delivered
    assert_equal 'Hello', received_notify_args[:subject]
    assert_equal 'World', received_notify_args[:content]
    assert_equal @user.username, received_notify_args[:from]
    assert_equal @user.email, received_notify_args[:from_email]
    assert_redirected_to root_path(locale: I18n.default_locale)
    assert_not_nil flash[:notice]
  end

  test 'invalid contact shows errors' do
    post contacts_path(locale: I18n.default_locale), params: { contact: { subject: '', content: '' } }
    assert_response :unprocessable_entity
    assert_not_nil flash[:alert]
  end

  test 'requires login' do
    sign_out @user
    get new_contact_path(locale: I18n.default_locale)
    assert_response :redirect
  end
end
