# frozen_string_literal: true

require 'test_helper'

class PagesHelperTest < ActionView::TestCase
  Event = Struct.new(:starts_at, :ends_at)

  test 'formats event dates in French' do
    I18n.with_locale(:fr) do
      assert_nil event_dates(Event.new(nil, nil))
      assert_equal '7 novembre 2026', event_dates(Event.new(Time.zone.local(2026, 11, 7, 10), nil))
      assert_equal '7-8 novembre 2026',
                   event_dates(Event.new(Time.zone.local(2026, 11, 7, 10), Time.zone.local(2026, 11, 8, 18)))
      assert_equal '30 mai 2026 – 1 juin 2026',
                   event_dates(Event.new(Time.zone.local(2026, 5, 30), Time.zone.local(2026, 6, 1)))
    end
  end

  test 'formats event dates in English' do
    I18n.with_locale(:en) do
      assert_equal 'November 7-8, 2026',
                   event_dates(Event.new(Time.zone.local(2026, 11, 7, 10), Time.zone.local(2026, 11, 8, 18)))
    end
  end
end
