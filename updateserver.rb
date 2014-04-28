#!/usr/bin/env ruby

require 'sinatra'
require 'sinatra/config_file'
require 'thin'
require 'json'
require 'date'
require 'geoip'


require_relative 'lib/models.rb'
require_relative 'lib/scraper.rb'
require_relative 'lib/stats.rb'

$CHANNELS = {
  "16"  => "stable",
  "2" => "prerelease",
}
geofile = "#{File.join(File.dirname(File.expand_path(__FILE__)),'geoip','GeoLiteCity.dat')}"
puts geofile
$GEOIP =  GeoIP.new(geofile)

class UpdateHTTP < Sinatra::Base
  # threaded - False: Will take requests on the reactor thread
  #            True:  Will queue request for background thread


  def initialize(job)
    puts job.nil?
    @statsJob = job
    super
  end

  set :public_folder, 'public'
  configure do
    set :threaded, false
  end

  # Send a response for pingdom
  get '/' do
    status 200
    body "pong"
  end

  get '/stats' do
    status 200
    erb :stats
  end

  get '/json/stats' do
    status 200
    headers \
      "Access-Control-Allow-Origin" => [ "http://www.rasplex.com", "https://www.rasplex.com"]
    body @statsJob.cachedStats
  end


  # Callback once a client is done updating
  get '/updated' do
    status 200
    current_time = DateTime.now  
    puts "Got #{params}"
    saveUpdateComplete(current_time, params, request.ip)
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
    begin
      puts "Got #{params}"
      current_time = DateTime.now  
      saveInstallRequest(current_time, params, request.ip)
      body JSON.dump Release.all
    rescue
      puts "Error saving install information..."
    end
  end

  post "/crashes" do 

    if params.has_key? "dumpfile64" and params.has_key? "serial" \
      and params.has_key? "revision" and params.has_key? "submitter_version"
      crash = Crash.new( 
        :serial            => params[:serial],
        :hwrev             => params[:revision],
        :submitter_version => params[:submitter_version]
      )

      if crash.save
        puts "saved and got id #{crash.id}"
      else
        crash.errors.each do |e|
          puts e
        end
      end

      id = crash.id
      crashpath = "crashdata/crash_#{id}.dump"

      crash.crash_path = crashpath
      crash.save

      File.open( crashpath , "w") do |f|
        f.write(params[:dumpfileb64])
      end
      puts "created crash #{id}"
      return "#{id}"
    else
      return "Invalid crash report, missing params"
    end
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

  stable = Release.all(:channel => "stable")
  if channel != "stable" and not stable.nil? and stable.length > 0
    candidates.push(stable)
  end

  releases = []

  candidates.each do | candidate |
    # Do any filtering here
    releases.push candidate
  end

  return releases
end

class UpdateServer


  def initialize(settings)

    @server = self
    @settings = settings

    @stats = nil
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

  def getStatsJob()
    return @stats
  end

  def start_scraping( interval )
    scraper = ScraperJob.new( interval )  
    scraper.scrape()
  end

  def start_stats( interval )
    @stats = StatsJob.new( interval, $GEOIP )  
    puts @stats.nil?
  end

  def run()

    # Start the reactor
    EM.run do

      server     = @settings.server    # 'thin'
      host       = @settings.host      # '0.0.0.0'
      port       = @settings.port      # '9000'
      interval   = @settings.interval  # '120'
      sinatra   = @server

      start_stats( interval )
      stats = @stats

      dispatch = Rack::Builder.app do
        map '/' do
          run UpdateHTTP.new(stats)
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

$stdout.sync = true
$stderr.sync = true


# start the application
updateServer = UpdateServer.new(settings)
updateServer.run 
