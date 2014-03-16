source 'https://rubygems.org'

gem 'sinatra'
gem 'thin'
gem "httparty", "~> 0.13.0"
gem "sinatra-contrib", "~> 1.4.2"
gem "datamapper", "~> 1.2.0"
gem "dm-sqlite-adapter", "~> 1.2.0"
gem "eventmachine", "~> 1.0.3"
gem 'capistrano', '~> 3.1.0'


group :production do
  gem 'mysql2'
  gem 'sqlite3'
  gem "sqlite3-ruby", "~> 1.3.3"
end

group :development, :test do
end


group :deploy do
  gem 'capistrano-bundler', '~> 1.1.2'
end


