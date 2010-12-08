# database.rb:  persisting stuff

require 'dm-core'
require 'dm-aggregates'
require 'dm-migrations'

class LogRecord
  include DataMapper::Resource
  
  property :id,         Serial
  property :nick,       String, :index=>true
  property :channel,    String
  property :message,    String
  property :happened,   DateTime, :index=>true
end

class Alias
  include DataMapper::Resource
  
  property :id,         Serial
  property :nick,       String, :unique_index => true
  property :email,      String
end