# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  # MUST BE THE FIRST IN THE BEFORE_ACTION STACK
  protect_from_forgery with: :exception

  # Must run before Devise's authenticate_user! so we can remember where to go back
  before_action :store_user_location!, if: :storable_location?

  before_action :authenticate_user!, unless: :devise_controller?
  before_action :set_locale
  before_action :redirect_to_cookie_locale_if_missing
  before_action :set_current_user
  before_action :configure_permitted_parameters, if: :devise_controller?

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :authenticated?

  private

  def authenticated?
    user_signed_in?
  end

  def set_current_user
    Current.user = current_user
  end

  def set_locale
    chosen = extract_locale
    chosen ||= cookies[:locale]
    chosen = chosen.to_s if chosen
    available = I18n.available_locales.map(&:to_s)
    chosen = I18n.default_locale unless available.include?(chosen)

    I18n.locale = chosen

    # Persist when explicitly selected via URL
    return unless params[:locale].present? && params[:locale].to_s != cookies[:locale]

    cookies[:locale] = { value: params[:locale].to_s, expires: 1.year.from_now }
  end

  def extract_locale
    parsed_locale = params[:locale]
    I18n.available_locales.map(&:to_s).include?(parsed_locale) ? parsed_locale : nil
  end

  def redirect_to_cookie_locale_if_missing
    return if params[:locale].present?
    return unless request.get? && request.format.html?

    cookie_locale = cookies[:locale]
    return if cookie_locale.blank?

    available = I18n.available_locales.map(&:to_s)
    return unless available.include?(cookie_locale)

    redirect_to url_for(locale: cookie_locale)
  end

  def default_url_options
    { locale: I18n.locale }
  end

  # Devise: ensure we remember the intended location (referer) for blocked non-GET actions
  def store_user_location!
    store_location_for(:user, request.referer)
  end

  def storable_location?
    !user_signed_in? && request.referer.present? && request.format.html? && !request.xhr?
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:username])
    devise_parameter_sanitizer.permit(:account_update, keys: [:username])
  end
end
