require 'test_helper'

class SidekiqUiTest < ActionDispatch::IntegrationTest
  test 'anonymous users get 404 at /sidekiq' do
    get '/sidekiq'

    assert_response :not_found
  end

  test 'non-admin users get 404 at /sidekiq' do
    login_as(users(:viewer))
    get '/sidekiq'

    assert_response :not_found
  end

  test 'admin users can reach /sidekiq' do
    login_as(users(:admin))
    get '/sidekiq'

    assert_response :success
  end
end
