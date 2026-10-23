source 'https://rubygems.org'

ruby '4.0.9'

gem 'rails', '~> 8.1.3'

gem 'pg', '~> 1.5'
gem 'propshaft'
gem 'puma', '>= 6.0'
gem 'redis', '~> 6.0'

gem 'cssbundling-rails'
gem 'importmap-rails'
gem 'stimulus-rails'
gem 'turbo-rails'

gem 'sidekiq', '~> 8.0'
gem 'sidekiq-cron', '~> 2.0'

gem 'dotenv-rails', '~> 3.1'
gem 'pagy', '~> 43.0'

gem 'omniauth', '~> 2.1'
gem 'omniauth_openid_connect', '~> 0.8'
gem 'omniauth-rails_csrf_protection', '~> 2.0'

gem 'chartkick', '~> 5.1'

gem 'tzinfo-data', platforms: %i[windows jruby]

gem 'bootsnap', require: false

gem 'thruster', require: false

gem 'image_processing', '~> 2.0'
gem 'prawn', '~> 2.5'

group :development, :test do
  gem 'debug', platforms: %i[mri windows], require: 'debug/prelude'

  gem 'bundler-audit', require: false
  gem 'minitest', '~> 6.0'
  gem 'minitest-mock'
end

group :development do
  gem 'web-console'
end

group :test do
  gem 'capybara'
  gem 'selenium-webdriver'
end
