# app.rb:  main

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

require 'optparse'

module Bzbot
  class App
    include Bzbot::Bot
    
    def main(args=nil)
      args ||= ARGV

      parse_opts(args)
      
      DataMapper.setup(:default, data_url)
      
      DataMapper.finalize
      DataMapper.auto_upgrade!

      extra_handlers.each do |re, template|
        add_simple_handler bzbot, Regexp.new(re), template
      end

      bzbot.start
    end
    
    def data_url
      bzbot_config[:data_url]
    end
    
    def email_domain
      bzbot_config[:email_domain]
    end
    
    def rooms
      bzbot_config[:rooms]
    end
    
    def bzbot_nick
      bzbot_config[:nick]
    end
    
    def bzbot_server
      bzbot_config[:server]
    end
    
    def bzbot_port
      bzbot_config[:port]
    end
    
    def xmlrpc_endpoint
      bzbot_config[:xmlrpc_endpoint]
    end
    
    def bzbot_bz_url
      bzbot_config[:bz_url]
    end
    
    def bz_product
      bzbot_config[:product]
    end
    
    def bz_max_results
      bzbot_config[:max_results]
    end
    
    def bzbot
      @bzbot ||= init_bzbot(self)
    end
    
    private
    
    def oparser
      @oparser ||= OptionParser.new do |opts|
        opts.banner = "Usage:  bzbot [options]"
      
        opts.on("-h", "--help", "shows this message") do
          raise OptionParser::InvalidOption.new
        end
      
        opts.on("--server HOSTNAME", "irc server (default #{bzbot_config[:server]})") do |h|
          bzbot_config[:server] = h
        end
        
        opts.on("--nick NICKNAME", "irc nickname (default #{bzbot_config[:nick]})") do |n|
          bzbot_config[:nick] = n
        end

        opts.on("--email-domain DOMAIN", "bugzilla email domain (default #{bzbot_config[:email_domain]})") do |d|
          bzbot_config[:email_domain] = d
        end
        
        opts.on("--bz-url URL", "bugzilla show-bug url (default #{bzbot_config[:bz_url]})") do |val|
          bzbot_config[:bz_url] = val
        end
        
        opts.on("--bz-product PRODUCT", "restrict bugzilla queries to PRODUCT (default \"#{bzbot_config[:product]}\")") do |val|
          bzbot_config[:product] = val
        end
        
        opts.on("--port NUM", Integer, "irc server port (default #{bzbot_config[:port]})") do |num|
          bzbot_config[:port] = num.to_i
        end
      
        opts.on("--room ROOM", "join irc room ROOM on startup") do |room|
          unless bzbot_config[:rooms_changed]
            bzbot_config[:rooms_changed] = true
            bzbot_config[:rooms] = ['#bzbot']
          end
          
          unless room =~ /^[#&]/
            room = "##{room}"
          end
          
          bzbot_config[:rooms] << room
        end
      
      end
    end
    
    def parse_opts(args)
      begin
        oparser.parse!(args)
      rescue OptionParser::InvalidOption
        puts oparser
        exit
      rescue OptionParser::InvalidArgument => ia
        puts ia
        puts oparser
        exit
      end
    end
    
    def bzbot_config
      @bzbot_config ||= {
        :data_url=>(ENV['BZBOT_DB_URL'] || "sqlite://#{ENV['PWD']}/bzbot.db"),
        :nick=>(ENV['BZBOT_NICK'] || 'bzbot'),
        :server=>(ENV['BZBOT_SERVER'] || 'localhost'),
        :port=>(ENV['BZBOT_PORT'].to_i rescue 6667),
        :rooms=>(ENV['BZBOT_ROOMS'].split(",") rescue ['#bzbot']),
        :rooms_changed=>false,
        :email_domain=>(ENV['BZBOT_EMAIL_DOMAIN'] || "redhat.com"),
        :xmlrpc_endpoint=>(ENV['BZBOT_API_ENDPOINT'] || "https://bugzilla.redhat.com/xmlrpc.cgi"),
        :bz_url=>(ENV['BZBOT_BZ_URL'] || "https://bugzilla.redhat.com/show_bug.cgi?id="),
        :product=>(ENV['BZBOT_PRODUCT'] || "Red Hat Enterprise MRG"),
        :max_results=>(ENV['BZBOT_MAX_RESULTS'].to_i rescue 20)
      }
    end
    
    def extra_handlers
      @extra_handlers ||= ENV.keys.grep(/^BZBOT_HANDLER_.*?_RE$/).inject({}) do |acc,key|
        begin
          re = Regexp.new(ENV[key], Regexp::IGNORECASE)
          template = ENV[key.gsub(/_RE$/, "_TMPL")]
          raise RuntimeError.new("bogus template value") unless template
          acc[re] = template
        rescue Exception => ex
          puts "warning:  can't add extra handler #{key}:  make sure it is set to a valid regular expression and that #{key.sub(/_RE$/, "_TMPL")} is also set"
        end
        
        acc
      end
    end
  end
end