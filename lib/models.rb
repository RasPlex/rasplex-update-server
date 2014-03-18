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
