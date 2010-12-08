# app.rb:  main

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

      add_simple_handler bzbot, /(uw#|gt)( |)([0-9]+)/i do
        "https://condor-wiki.cs.wisc.edu/index.cgi/tktview?tn=#{match[2]}"
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
  end
end