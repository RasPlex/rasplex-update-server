
require 'date'
require 'data_mapper'
require 'dm-migrations'

class UpdateCompleted
  include DataMapper::Resource
  property :id,          Serial
  property :serial,      String, :required => true
  property :hwrev,       String, :required => true
  property :ipaddr,      String, :required => true
  property :version,     String, :required => true
  property :oldversion,  String, :required => true
  property :channel,     String, :required => true
  property :time,        DateTime, :required => true
end


class InstallRequest
  include DataMapper::Resource
  property :id,          Serial
  property :ipaddr,      String, :required => true
  property :platform,    String, :required => true
  property :time,        DateTime, :required => true
end




class UpdateRequest
  include DataMapper::Resource
  property :id,          Serial
  property :serial,      String, :required => true
  property :hwrev,       String, :required => true
  property :ipaddr,      String, :required => true
  property :version,     String, :required => true
  property :channel,     String, :required => true
  property :time,        DateTime, :required => true
end



class Release
  include DataMapper::Resource
  property :id,          Serial
  property :install_url, String, :required => true, :length => 200 
  property :install_sum, String, :required => true, :length => 100
  property :update_url,  String, :required => true, :length => 200
  property :update_sum,  String, :required => true, :length => 100
  property :version,     String, :required => true
  property :channel,     String, :required => true
  property :autoupdate,  Boolean, :required => false
  property :time,        DateTime, :required => true
  property :notes,       String, :required => true, :length => 800
end


class Crash
  include DataMapper::Resource
  property :id,                Serial
  property :version, String, :required => true, :length => 100
  property :submitter_version, String, :required => true, :length => 100
  property :crash_path,        String, :required => true, :length => 200, :default => "none" 
  property :serial,            String, :required => true 
  property :hwrev,             String, :required => true 
  property :ipaddr,            String, :required => true
  property :time,              DateTime, :required => true
end


def getStats(geo_db)
  stats = {
    :users => {
      :days_ago =>{},
      :total => 0,
    },
    :installs => {
      :days_ago =>{},
      :total => {},
    },
    :last_update => DateTime.now,

  }
  for lookback in (1..7).to_a.reverse
    value = repository(:default).adapter.select('SELECT COUNT(DISTINCT serial) 
                                                  FROM update_requests 
                                                  WHERE time BETWEEN date_sub(now(),INTERVAL ? DAY) 
                                                  AND date_sub(now(),INTERVAL ? DAY);', lookback, lookback-1)
    stats[:users][:days_ago][lookback] = value
  end

  stats[:users][:total] = repository(:default).adapter.select('SELECT COUNT(DISTINCT serial) 
                                                                FROM update_requests;')


  for lookback in (1..7).to_a.reverse
    value = repository(:default).adapter.select('SELECT platform, COUNT(DISTINCT ipaddr) 
                                                  FROM install_requests 
                                                  WHERE time BETWEEN date_sub(now(),INTERVAL ? DAY) 
                                                  AND date_sub(now(),INTERVAL ? DAY)
                                                  GROUP BY platform;', lookback, lookback-1)
    stats[:installs][:days_ago][lookback] = {}
    value.each do | platform |
       stats[:installs][:days_ago][lookback][platform.platform] = platform["count(distinct ipaddr)"]
    end
  end

  value = repository(:default).adapter.select('SELECT platform, COUNT(DISTINCT ipaddr) 
                                                                  FROM install_requests
                                                                  GROUP BY platform;')

  value.each do | platform |
     stats[:installs][:total][platform.platform] = platform["count(distinct ipaddr)"]
  end





  return JSON.generate(stats)
end

def saveUpdateComplete(current_time, params, source)
      
  upcomplete = UpdateCompleted.new(
      :serial     =>  params['serial'],
      :hwrev      =>  params['revision'],
      :version    =>  params['version'],
      :oldversion =>  params['fromVersion'],
      :channel    =>  params['channel'],
      :ipaddr     =>  source,
      :time       =>  current_time 
  )
  if upcomplete.save
    puts "#{Time.now.utc} Update request saved #{JSON.pretty_generate(upcomplete)}"
  else
    upcomplete.errors.each do |e|
      puts e
    end
  end

end 

def saveUpdateRequest(current_time, params, source)
      
  upreq = UpdateRequest.new(
      :serial  =>  params['serial'],
      :hwrev   =>  params['revision'],
      :version =>  params['version'],
      :channel =>  params['channel'],
      :ipaddr  =>  source,
      :time    =>  current_time 
  )
  if upreq.save
    puts "#{Time.now.utc} Update request saved #{JSON.pretty_generate(upreq)}"
  else
    upreq.errors.each do |e|
      puts e
    end
  end

end 

def saveInstallRequest(current_time, params, source)

  if params.has_key? 'platform'
    platform = params['platform']
  else
    platform = params['unknown']
  end
      
  instreq = InstallRequest.new(
      :platform  =>  platform,
      :ipaddr    =>  source,
      :time      =>  current_time 
  )

  if instreq.save
    puts "#{Time.now.utc} Install request saved #{JSON.pretty_generate(instreq)}"
  else
    instreq.errors.each do |e|
      puts e
    end
  end

end 
