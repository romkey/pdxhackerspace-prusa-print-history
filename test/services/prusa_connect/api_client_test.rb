require 'test_helper'

module PrusaConnect
  class ApiClientTest < ActiveSupport::TestCase
    setup do
      @credential = PrusaConnectCredential.create!(refresh_token: 'refresh-1')
      @client = ApiClient.new(credential: @credential)
    end

    def response(klass, body = '{}', code = '200')
      res = klass.new('1.1', code, klass.name.demodulize)
      res.instance_variable_set(:@read, true)
      res.instance_variable_set(:@body, body)
      res
    end

    def stub_http(responses)
      requests = []
      fake = Object.new
      fake.define_singleton_method(:request) do |req|
        requests << req
        responses.shift
      end
      Net::HTTP.stub(:start, ->(*_a, **_k, &block) { block.call(fake) }) { yield(requests) }
    end

    test 'refreshes the access token, persists the rotated refresh token and sends a bearer header' do
      token = response(Net::HTTPOK, { access_token: 'access-1', refresh_token: 'refresh-2', expires_in: 3600 }.to_json)
      printers = response(Net::HTTPOK, { printers: [{ uuid: 'u1' }] }.to_json)

      stub_http([token, printers]) do |requests|
        assert_equal [{ 'uuid' => 'u1' }], @client.printers
        assert_equal "grant_type=refresh_token&refresh_token=refresh-1&client_id=#{ApiClient::CLIENT_ID}",
                     requests.first.body
        assert_equal 'Bearer access-1', requests.last['Authorization']
      end

      @credential.reload

      assert_equal 'refresh-2', @credential.refresh_token
      assert @credential.access_token_fresh?
    end

    test 'reuses a fresh access token without refreshing' do
      @credential.store_tokens!(access_token: 'still-good', expires_in: 3600)

      stub_http([response(Net::HTTPOK, { jobs: [{ id: 1 }] }.to_json)]) do |requests|
        assert_equal [{ 'id' => 1 }], @client.jobs('u1')
        assert_equal 1, requests.size
      end
    end

    test 'a rejected refresh token raises AuthError and records the error' do
      stub_http([response(Net::HTTPBadRequest, '{}', '400')]) do
        assert_raises(AuthError) { @client.printers }
      end

      assert_match(/refresh failed/, @credential.reload.last_error)
    end

    test 'raises AuthError when no token is configured' do
      assert_raises(AuthError) { ApiClient.new(credential: nil).printers }
    end
  end
end
