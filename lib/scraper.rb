require 'httparty'
require 'json'
require 'yaml'
require 'date'


require_relative 'models.rb'

class ScraperJob

  def initialize( interval )
    # make this a config constant
    EM.add_periodic_timer(interval) do
      scrape
    end
  end

  def scrape


    puts "#{Time.now.utc} Ran a scrape"
    response = HTTParty.get('https://api.github.com/repos/Rasplex/Rasplex/releases', :headers => {"User-Agent" => "Wget/1.14 (linux-gnu)"})

    #puts response.body, response.code, response.message, response.headers.inspect

    Release.all.destroy

    if response.code == 200
      parse response.body
    end
  end

  def parse ( body )

    baseurl = "https://github.com/RasPlex/RasPlex/releases/download"

    payload = JSON.parse(body)
  
    payload.each do | release |

      body = YAML.load(release["body"])
      name = release["name"]
      channel = release["prerelease"] ? "prerelease" : "stable"

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
            :version     => name,
            :channel     => channel,
            :autoupdate  => true,
            :time        => time,
            :notes       => notes 
        )
        if release.save
          puts "#{Time.now.utc} Release #{name} added #{JSON.pretty_generate(release)}"
        else
          release.errors.each do |e|
            puts e
          end
        end

      end

    end

  end
end


