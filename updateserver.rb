
require 'sinatra'
require 'sinatra/config_file'

require 'json'
require 'yaml'
require 'date'

require 'thin'
require 'httparty'
require 'data_mapper'
require 'dm-migrations'


class UpdateRequest
  include DataMapper::Resource
  property :id,          Serial
  property :serial,      String, :required => true
  property :version,     String, :required => true
  property :time,        DateTime, :required => true
  property :release,     String
end


class Release
  include DataMapper::Resource
  property :id,          Serial
  property :install_url, String, :required => true, :length => 200 
  property :install_sum, String, :required => true, :length => 100
  property :update_url,  String, :required => true, :length => 200
  property :update_sum,  String, :required => true, :length => 100
  property :version,     String, :required => true
  property :autoupdate,  Boolean, :required => true
  property :time,        DateTime, :required => true
  property :notes,       String, :required => true, :length => 800
end

class ScraperJob

  def scrape

    EM.defer do

      response = HTTParty.get('https://api.github.com/repos/Rasplex/Rasplex/releases', :headers => {"User-Agent" => "Wget/1.14 (linux-gnu)"})

      #puts response.body, response.code, response.message, response.headers.inspect

      if response.code == 200
        parse response.body
      end
      sleep 120 # make this a config constant, but we are limited to 1 request / minute

      EM.defer scrape
    end
  end

  def parse ( body )

    baseurl = "https://github.com/RasPlex/RasPlex/releases/download"

    payload = JSON.parse(body)
  
    payload.each do | release |

      body = YAML.load(release["body"])
      puts body
      name = release["name"]
      autoupdate = release["prerelease"] == false

      install = nil
      update = nil
      release["assets"].each do | asset |

        if asset['name'] =~ /\.img\.gz$/  
          install = asset
          install["download_url"] = "#{baseurl}/#{name}/#{asset['name']}"
          body["install"].each do | data |
            if data.has_key?("md5sum")
              install["checksum"] = data["md5sum"]
            end
          end

        elsif asset['name'] =~ /\.tar\.gz$/
          update = asset
          update["download_url"] = "#{baseurl}/#{name}/#{asset['name']}"
          body["update"].each do | data |
            if data.has_key?("shasum")
              update["checksum"] = data["shasum"]
            end
          end
        end

      end

      time = DateTime.iso8601(release["published_at"])

      notes = body["changes"].join("\n")
    
      if not Release.last(:version => name ) and not install.nil? and not update.nil?
      
        release = Release.new(
            :install_url => install["download_url"],
            :install_sum => install["checksum"],
            :update_url  => update["download_url"],
            :update_sum  => update["checksum"],
            :autoupdate  => autoupdate,
            :version     => name,
            :time        => time,
            :notes       =>  notes 
        )
        if release.save
          puts "Release #{name} added"
        else
          release.errors.each do |e|
            puts e
          end
        end

      end

    end

  end
end



class UpdateHTTP < Sinatra::Base
  # threaded - False: Will take requests on the reactor thread
  #            True:  Will queue request for background thread
  configure do
    set :threaded, true
  end

  # Request runs on the reactor thread (with threaded set to false)
  get '/update' do
    # check that we have a spell for this profile, or else throw an error
    status 200
    releases = Release.all
    erb :update, :locals => { :releases => releases }
  end

  # Request runs on the reactor thread (with threaded set to false)
  get '/install' do
    # check that we have a spell for this profile, or else throw an error
    status 200
    body JSON.dump Release.all
  end

end


class UpdateServer

  def initialize()

    db_path = "#{File.join(File.dirname(File.expand_path(__FILE__)),'db','development.db')}"
    db_url = "sqlite3://#{db_path}"

    DataMapper.setup :default, db_url 
    DataMapper.finalize
    DataMapper.auto_upgrade!


  end


  def start_scraping
    scraper = ScraperJob.new()  
    scraper.scrape()
  end

  def run(opts={})

    # Start the reactor
    EM.run do
      # define some defaults for our app
      server  = opts[:server] || 'thin'
      host    = opts[:host]   || '0.0.0.0'
      port    = opts[:port]   || '8080'

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
      start_scraping


    end
  
  end

  def init_sighandlers
    trap(:INT)  {"Got interrupt"; EM.stop(); exit }
    trap(:TERM) {"Got term";      EM.stop(); exit }
    trap(:KILL) {"Got kill";      EM.stop(); exit }
  end

end
# start the applicatin
updateServer = UpdateServer.new
updateServer.run :port => 8080
