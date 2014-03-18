#!/usr/bin/env ruby

require 'sinatra'
require 'sinatra/config_file'
require 'thin'
require 'json'
require 'date'


require_relative 'lib/models.rb'
require_relative 'lib/scraper.rb'

$CHANNELS = {
  "16"  => "stable",
  "2" => "prerelease",
}

class UpdateHTTP < Sinatra::Base
  # threaded - False: Will take requests on the reactor thread
  #            True:  Will queue request for background thread
  configure do
    set :threaded, false
  end

  # Send a response for pingdom
  get '/' do
    status 200
    body "pong"
  end


  # Callback once a client is done updating
  get '/updated' do
    status 200
    current_time = DateTime.now  
    saveUpdateComplete(current_time, params, request.ip)
    puts "Got #{params}"
    body "Thanks for updating"
  end


  # Request to list available updates in channel
  get '/update' do
    status 200
    current_time = DateTime.now  
    releases = selectReleases(current_time, params, request.ip)
    puts "Got #{params}"
    erb :update, :locals => { :releases => releases }
  end

  # Request to list available install images
  get '/install' do
    status 200
    body JSON.dump Release.all
  end

end

def selectReleases(current_time, params, source)
  saveUpdateRequest(current_time, params, source)

  

  channel = "stable"
  if params["channel"] and $CHANNELS.has_key? params["channel"]
    channel = $CHANNELS[params["channel"]]
  end
  puts "Using channel #{channel}"

  candidates = Release.all(:channel => channel.downcase)

  releases = []

  candidates.each do | candidate |
    # Do any filtering here
    releases.push candidate
  end

  return releases
end

class UpdateServer


  def initialize(settings)

    @settings = settings

    if ENV['UPDATER_ENVIRONMENT'] == "production"
      puts "#{Time.now.utc} Running as production"
      db_url = "mysql://#{settings.db['user']}:#{settings.db['password']}@#{settings.db['hostname']}/#{settings.db['dbname']}"
    else
      db_path = "#{File.join(File.dirname(File.expand_path(__FILE__)),'db','development.db')}"
      puts "Using DB at #{db_path}"
      db_url = "sqlite3://#{db_path}"
    end

    DataMapper.setup :default, db_url 
    DataMapper.finalize
    DataMapper.auto_upgrade!
#    UpdateRequest.auto_migrate!
#    Release.auto_migrate!


  end


  def start_scraping( interval )
    scraper = ScraperJob.new( interval )  
    scraper.scrape()
  end

  def run()

    # Start the reactor
    EM.run do

      server     = @settings.server    # 'thin'
      host       = @settings.host      # '0.0.0.0'
      port       = @settings.port      # '9000'
      interval   = @settings.interval  # '120'

      dispatch = Rack::Builder.app do
        map '/' do
          run UpdateHTTP.new
        end
      end

      # NOTE that we have to use an EM-compatible web-server. There
      # might be more, but these are some that are currently available.
      unless ['thin', 'hatetepe', 'goliath'].include? server
        raise "Need an EM webserver, but #{server} isn't"
      end

      # Start the web server. Note that you are free to run other tasks
      # within your EM instance.
      Rack::Server.start({
        app:    dispatch,
        server: server,
        Host:   host,
        Port:   port
      })
      init_sighandlers
      start_scraping(interval)


    end
  
  end

  # Needed during testing
  def init_sighandlers
    trap(:INT)  {"Got interrupt"; EM.stop(); exit }
    trap(:TERM) {"Got term";      EM.stop(); exit }
    trap(:KILL) {"Got kill";      EM.stop(); exit }
  end

end
# Load configs
config = "#{File.join(File.dirname(File.expand_path(__FILE__)),'config','config.yml')}"
database_config = "#{File.join(File.dirname(File.expand_path(__FILE__)),'config','database.yml')}"
config_file config
config_file database_config

$stdout.reopen(settings.logfile, "a")
$stderr.reopen(settings.logfile, "a")
$stdout.sync = true
$stdout.sync = true


# start the application
updateServer = UpdateServer.new(settings)
updateServer.run 
