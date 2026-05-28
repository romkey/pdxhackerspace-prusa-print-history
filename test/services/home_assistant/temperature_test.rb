require 'test_helper'

module HomeAssistant
  class TemperatureTest < ActiveSupport::TestCase
    test 'leaves celsius values unchanged' do
      assert_in_delta 21.5, Temperature.to_celsius(21.5, '°C'), 0.0001
      assert_in_delta 21.5, Temperature.to_celsius(21.5, 'C'), 0.0001
      assert_in_delta 21.5, Temperature.to_celsius(21.5, nil), 0.0001
    end

    test 'converts fahrenheit to celsius' do
      assert_in_delta 21.111, Temperature.to_celsius(70, '°F'), 0.001
      assert_in_delta 21.111, Temperature.to_celsius(70, 'F'), 0.001
    end

    test 'converts kelvin to celsius' do
      assert_in_delta 20.85, Temperature.to_celsius(294.0, 'K'), 0.01
    end
  end
end
