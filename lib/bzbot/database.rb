# database.rb:  persisting stuff

# Copyright 2010 Red Hat, Inc., and William C. Benton
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

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
  
  property :nick,       String, :key=>true
  property :email,      String
end

class User
  include DataMapper::Resource
  
  property :nick,           String, :key=>true
  property :queries,        Integer. :default=>0
  property :nice_comments,  Integer. :default=>0
  property :mean_comments,  Integer. :default=>0
  property :ventriloquism,  Integer. :default=>0
end