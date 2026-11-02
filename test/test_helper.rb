# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'
require 'view_component/test_helpers'
require 'devise'
require 'minitest/mock'

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    include ViewComponent::TestHelpers
    include ActiveJob::TestHelper

    setup do
      ActiveJob::Base.queue_adapter = :test
      # Requests set I18n.locale on the shared thread: start every test from the default
      I18n.locale = I18n.default_locale # rubocop:disable Rails/I18nLocaleAssignment
    end
  end
end

module ActionDispatch
  class IntegrationTest
    include ActiveJob::TestHelper
    include Devise::Test::IntegrationHelpers

    setup do
      ActiveJob::Base.queue_adapter = :test
      # Requests set I18n.locale on the shared thread: start every test from the default
      I18n.locale = I18n.default_locale # rubocop:disable Rails/I18nLocaleAssignment
    end
  end
end
