# frozen_string_literal: true

class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  has_many :game_participations, class_name: 'Game::Participation', dependent: :destroy
  has_many :game_events, through: :game_participations, class_name: 'Game::Event'
  has_many :game_systems, through: :game_events, class_name: 'Game::System'
  has_many :tournament_registrations, class_name: 'Tournament::Registration', dependent: :destroy
  has_many :tournament_matches_as_a, class_name: 'Tournament::Match', foreign_key: 'a_user_id',
                                     inverse_of: :a_user, dependent: :nullify
  has_many :tournament_matches_as_b, class_name: 'Tournament::Match', foreign_key: 'b_user_id',
                                     inverse_of: :b_user, dependent: :nullify
  # Legacy custom authentication removed in favor of Devise

  validates :username, presence: true, uniqueness: true
  # Devise expects `email`
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  before_validation :generate_admin_password_if_blank, on: :create

  private

  # When an Admin creates a user from Avo and leaves password empty, generate a secure password.
  def generate_admin_password_if_blank
    return unless Current.respond_to?(:admin) && Current.admin.present?
    return unless password.blank? && password_confirmation.blank?

    generated = SecureRandom.base64(16)
    self.password = generated
    self.password_confirmation = generated
  end
end
