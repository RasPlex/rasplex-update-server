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


