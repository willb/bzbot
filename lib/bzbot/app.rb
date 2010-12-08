# app.rb:  main

module Bzbot
  class App
    include Bzbot::Bot
    
    def main(args=nil)
      args ||= ARGV
      
      DataMapper.setup(:default, data_url)
      
      DataMapper.finalize
      DataMapper.auto_upgrade!

      add_simple_handler bzbot, /(uw#|gt)( |)([0-9]+)/i do |nick, match|
        "#{nick}: https://condor-wiki.cs.wisc.edu/index.cgi/tktview?tn=#{match[2]}"
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
    
    def bzbot_config
      @bzbot_config ||= {
        :data_url=>(ENV['BZBOT_DB_URL'] || "sqlite://#{ENV['PWD']}/bzbot.db"),
        :nick=>(ENV['BZBOT_NICK'] || 'bzbot'),
        :server=>(ENV['BZBOT_SERVER'] || 'localhost'),
        :port=>(ENV['BZBOT_PORT'].to_i rescue 6667),
        :rooms=>(ENV['BZBOT_ROOMS'].split(",") rescue ['#bzbot']),
        :email_domain=>(ENV['BZBOT_EMAIL_DOMAIN'] || "redhat.com"),
        :xmlrpc_endpoint=>(ENV['BZBOT_API_ENDPOINT'] || "https://bugzilla.redhat.com/xmlrpc.cgi"),
        :bz_url=>(ENV['BZBOT_BZ_URL'] || "https://bugzilla.redhat.com/show_bug.cgi?id="),
        :product=>(ENV['BZBOT_PRODUCT'] || "Red Hat Enterprise MRG"),
        :max_results=>(ENV['BZBOT_MAX_RESULTS'].to_i rescue 20)
      }
    end
  end
end