require 'httparty'
require 'json'
require 'yaml'
require 'date'


require_relative 'models.rb'

class ScraperJob

  def initialize( interval, apikey )
    # make this a config constant
    @apikey = apikey
    EM.add_periodic_timer(interval) do
      scrape
    end
  end

  def scrape


    puts "#{Time.now.utc} Ran a scrape"
    response = HTTParty.get('https://api.github.com/repos/Rasplex/Rasplex/releases', :headers => {"User-Agent" => "Wget/1.14 (linux-gnu)",
                                                                                                  "Authorization" => "token #{@apikey}"
                                                                                                 })

    #puts response.body, response.code, response.message, response.headers.inspect


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

      puts release["draft"]
      if body.has_key? "channel" # allow override of the channel via yaml
        channel = body["channel"]
        puts "Adding release to channel #{channel}"
      elsif release["draft"]
        channel = "beta" 
      else
        channel = release["prerelease"] ? "prerelease" : "stable"
      end

      install = nil
      update = nil
      release["assets"].each do | asset |

        puts asset['name']
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

      if not release["draft"]
        time = DateTime.iso8601(release["published_at"])
      else
        time = DateTime.now.iso8601
      end

      if body.has_key? "changes"
        notes = body["changes"].join("\n")
      else
        puts "Release notes are required"
        notes = "Invalid release - no release notes"
      end
#      deprecated = Release.all(:version.not => name)
#      deprecated.each do | dep |
#        puts "Version #{dep.version} is deprecated, deleting"
#        dep.destroy()
#      end
#
      if not Release.last(:version => name ) and not install.nil? and not update.nil?
        puts "Saving release"

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

      else
        puts "Not saving release"
      end

    end

  end
end


