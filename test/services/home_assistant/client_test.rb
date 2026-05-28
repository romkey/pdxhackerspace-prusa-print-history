require 'test_helper'

module HomeAssistant
  class ClientTest < ActiveSupport::TestCase
    setup do
      @client = Client.new(base_url: 'http://homeassistant.local:8123', token: 'ha-token')
    end

    test 'configured? requires both url and token' do
      assert_predicate @client, :configured?
      assert_not Client.new(base_url: nil, token: 'x').configured?
      assert_not Client.new(base_url: 'http://x', token: nil).configured?
    end

    test 'state returns the state string for an entity' do
      stub_http(StubResponse.ok({ 'state' => '21.5' }.to_json)) do |captured|
        assert_equal '21.5', @client.state('sensor.ambient_temperature')
        assert_equal '/api/states/sensor.ambient_temperature', captured[:request].path
        assert_equal 'Bearer ha-token', captured[:request]['Authorization']
      end
    end

    test 'temperature_celsius converts fahrenheit entities to celsius' do
      body = {
        'state' => '70',
        'attributes' => { 'unit_of_measurement' => '°F' }
      }.to_json

      stub_http(StubResponse.ok(body)) do
        assert_in_delta 21.111, @client.temperature_celsius('sensor.ambient_temperature'), 0.001
      end
    end

    test 'temperature_celsius leaves celsius entities unchanged' do
      body = {
        'state' => '21.5',
        'attributes' => { 'unit_of_measurement' => '°C' }
      }.to_json

      stub_http(StubResponse.ok(body)) do
        assert_in_delta 21.5, @client.temperature_celsius('sensor.ambient_temperature'), 0.0001
      end
    end

    test 'temperature_celsius returns nil for unavailable entities' do
      stub_http(StubResponse.ok({ 'state' => 'unavailable', 'attributes' => {} }.to_json)) do
        assert_nil @client.temperature_celsius('sensor.ambient_temperature')
      end
    end

    test 'numeric_state parses floats and treats unknown/unavailable as nil' do
      stub_http(StubResponse.ok({ 'state' => '22.3' }.to_json)) do
        assert_in_delta 22.3, @client.numeric_state('sensor.foo'), 0.0001
      end

      stub_http(StubResponse.ok({ 'state' => 'unknown' }.to_json)) do
        assert_nil @client.numeric_state('sensor.foo')
      end

      stub_http(StubResponse.ok({ 'state' => 'unavailable' }.to_json)) do
        assert_nil @client.numeric_state('sensor.foo')
      end
    end

    test 'numeric_state returns nil when entity is missing (404)' do
      stub_http(StubResponse.new(Net::HTTPNotFound, '404')) do
        assert_nil @client.numeric_state('sensor.missing')
      end
    end

    test 'available? returns true when API responds healthy' do
      stub_http(StubResponse.ok({ 'message' => 'API running.' }.to_json)) do
        assert_predicate @client, :available?
      end
    end

    test 'available? returns false when not configured or unreachable' do
      assert_not Client.new(base_url: nil, token: nil).available?

      Net::HTTP.stub(:start, ->(*_args, **_kwargs, &_block) { raise Errno::ECONNREFUSED }) do
        assert_not @client.available?
      end
    end

    private

    StubResponse = Struct.new(:klass, :code, :body) do
      def self.ok(body)
        new(Net::HTTPOK, '200', body)
      end

      def build
        response = klass.new('1.1', code, klass.name.demodulize)
        response.instance_variable_set(:@read, true)
        response.body = body if body
        response
      end
    end

    def stub_http(stub_response)
      captured = {}
      fake_http = Object.new
      fake_http.define_singleton_method(:request) do |request|
        captured[:request] = request
        stub_response.build
      end

      Net::HTTP.stub(:start, lambda { |*_args, **_kwargs, &block|
        block.call(fake_http)
      }) do
        yield(captured)
      end
    end
  end
end
