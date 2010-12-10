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

require 'isaac/bot'
require 'xmlrpc/client'

require 'erb'

module Bzbot
  module Bot
    def add_simple_handler(bot,pattern,template)
      bot.on :channel, pattern do
        record_log
        increment_counter(:queries)
        the_message = ERB.new(template).result(self.send(:binding))
        msg self.channel, the_message.to_s
      end
    end
    
    def init_bzbot(the_app)
      Isaac::Bot.new do
        @app = the_app
        
        def app
          @app
        end
        
        configure do |c|
          c.nick = app.bzbot_nick
          c.server = app.bzbot_server
          c.port = app.bzbot_port
        end
    
        on :connect do
          join *app.rooms
          init_xmlrpc_bz
        end
    
        on :channel, /^bzbot[:,]{0,1}\s*desc(ribe|)( |)([0-9]+)/ do
          record_log
          increment_counter(:times_described)
          
          bzdesc = ""
    
          begin
            bug_id = match[2].to_i
            bugs = @xmlrpc_bz.call("Bug.search", {"bug_id"=>bug_id})["bugs"]
            if bugs.size == 1
              bzdesc = " (#{bugs[0]["short_desc"]})"
              msg channel, "#{nick}: BZ #{bug_id}:  #{bzdesc} #{app.bzbot_bz_url}#{bug_id}"
            else
              msg channel, "#{nick}: Sorry, I couldn't find that bug."
            end 
          rescue Exception
            init_xmlrpc_bz
            msg channel, "#{nick}: Sorry, I ran into some trouble with that request.  You might want to try again."
            return
          end
        end
    
        on :channel, /(bz|BZ)( |)([0-9]+)/ do
          record_log
          increment_counter(:queries)
          
          msg channel, "#{nick}: #{app.bzbot_bz_url}#{match[2]}"
        end
    
        on :channel, /^bzbot[:,]{0,1}\s*help$/i do
          record_log
          msg nick, "I will respond to messages on the channel of the form BZ([0-9]+) or UW#([0-9]+) and send back a link to the relevant BZ or gittrac ticket.  I also have some other features."
        end
    
        on :channel, /(bzbot[:,]{0,1}\s*(thanks|thx)(.*)|(thanks|thx)(,|)\s*bzbot(.*))/i do
          record_log
          increment_counter(:nice_comments)
          
          random_welcome
        end
    
        on :channel, /bzbot\s*(rocks|rules|is cool|is great)/i do
          record_log
          increment_counter(:nice_comments)

          random_happy
        end
    
        on :channel, /bzbot\s*(sucks|blows|is worse than gradware|is an embarrassment to Ruby hippies everywhere)/i do
          record_log
          increment_counter(:mean_comments)
          
          random_sad
        end
    
        on :private, /^emote (.*?) on (#.*)$/ do
          record_log
          increment_counter(:ventriloquism)
          
          action match[1], match[0]
        end
    
        on :private, /^say (.*?) on (#.*)$/ do
          record_log
          increment_counter(:ventriloquism)

          msg match[1], match[0]
        end
    
        on :private, /^alias (.*?)=(.*)$/ do
          record_log
          begin
            a = Alias.all(:nick=>match[0])
            a[0].delete if a.size == 1
            Alias.create(:nick=>match[0], :email=>match[1])
            msg nick, "#{match[0]} is an alias for #{match[1]}@#{app.email_domain}"
          rescue Exception
            msg nick, "Sorry, I couldn't do that."
          end
        end
    
        on :channel, /^bzbot[:,]{0,1}\s*apropos\s*(.*)$/ do
          record_log
          increment_counter(:times_searched)
    
          words = match[0].split
          bugs = {}
    
          begin
            words.each do |word|
              result = @xmlrpc_bz.call("Bug.search", "quicksearch"=>word, "product"=>app.bz_product)
              result["bugs"].each do |bug|
                bugs[bug["bug_id"]] = bug
              end
            end
          rescue Exception
            init_xmlrpc_bz
            msg channel, "#{nick}: Sorry, I ran into some trouble with that request.  You might want to try again."
          end
    
          bzcount = bugs.keys.size
    
          case bzcount
          when 0 
            msg channel, "#{nick}:  I found no related bugs, sorry."
          when 1
            bug_id = bugs.keys[0]
            bug_desc = bugs[bug_id]["short_desc"]
            bug_url = "#{app.bzbot_bz_url}#{bug_id}"
            msg channel, "#{nick}:  I found one related bug:  BZ #{bug_id}:  #{bug_desc} #{bug_url}"
          when 2..app.bz_max_results
            msg channel, "#{nick}:  I found #{bzcount} related bugs; check your PM."
            dump_bugs_priv(nick, bugs)
          else
            msg channel, "#{nick}:  I found #{bzcount} related bugs but am unwilling to spam you; check your PM for the first #{app.bz_max_results}."
            dump_bugs_priv(nick, bugs)
          end  
        end
    
        on :channel, /^bzbot[:,]{0,1}\s*(.*?) is bored$/ do
          record_log
          increment_counter(:times_bored, normalize_nick(match[0]))

          bored(match[0])
        end
    
        on :channel, /^bzbot[:,]{0,1}\s*(I'm|I am) bored$/i do
          record_log
          increment_counter(:times_bored)

          bored(normalize_nick(nick))
        end
    
        on :channel, /^bzbot[:,]{0,1}\s*(disconnect|deactivate|quit|go away)$/i do
          record_log
          msg channel, "I'm sorry, #{nick}, I'm afraid I can't do that."
        end
    
        on :channel, /wittgenstein/i do
          record_log
          random_positivism
        end
    
        on :private, /.*/ do
          record_log
        end
    
        helpers do
          def record_log
            LogRecord.create(:nick=>nick, :channel=>channel, :message=>message, :happened=>Time.now)
          end
    
          def init_xmlrpc_bz
            @xmlrpc_bz = XMLRPC::Client.new2(app.xmlrpc_endpoint)
          end
    
          # removes leading and trailing underscores
          def normalize_nick(n)
            n.gsub(/(^_*)|(_*$)/, "")
          end
          
          def increment_counter(which,n=nil)
            n ||= normalize_nick(nick)
            user = User.first_or_create(:nick=>n)
            user.send("#{which}=", user.send(which) + 1)
            user.save
          end
    
          def bored(name)
    
            aliased_email, = Alias.all(:nick=>name)
    
            name = aliased_email.email if aliased_email
    
            begin
              bugs = @xmlrpc_bz.call("Bug.search", {"product"=>app.bz_product, "assigned_to"=>"#{name}@#{app.email_domain}", "bug_status"=>"ASSIGNED"})["bugs"]
              if bugs.size == 0
                msg channel, "#{nick}: I can't help with that, sorry."
              else
                bug = bugs.sort_by {rand}.pop
                short_desc = bug["short_desc"]
                bug_id = bug["bug_id"]
                msg channel, "#{nick}:  might I suggest \"#{short_desc}\"?  #{app.bzbot_bz_url}#{bug_id}"
              end
            rescue Exception
              init_xmlrpc_bz
              msg channel, "#{nick}: I can't help with that, sorry."
            end
          end
    
          def dump_bugs_priv(nick, bugs)
            counter = 0
            bugs.each do |bug_id, bug|
              bug_desc = bug["short_desc"]
              bug_url = "#{app.bzbot_bz_url}#{bug_id}"
              msg nick, "BZ #{bug_id}:  #{bug_desc}  #{bug_url}"
              counter = counter + 1
              break if counter == app.bz_max_results
            end
          end
    
          def random_welcome
            messages = ["you're welcome", "just doing my job", "np", "my pleasure", "you're welcome", "de nada", "of course!", "not at all", "/blushes", "/is flattered", "/appreciates that #{nick} recognizes a job well done", "I am putting myself to the fullest possible use, which is all I think that any conscious entity can ever hope to do."]
            random_msg(messages)
          end
    
          def random_happy
            messages = ["/grins", "/beams", "/dances like Snoopy", "hey, thanks!", "glad you noticed", "/is modest, too", "/is, by any practical definition of the words, foolproof and incapable of error"]
            random_msg(messages)
          end
    
          def random_sad
            messages = ["/cries softly to itself", "/sulks", "/doesn't really like #{nick}, either", "/knows it has made some very poor decisions recently, but can give #{nick} my complete assurance that my work will be back to normal", "I can see you're really upset about this. I honestly think you ought to sit down calmly, take a stress pill, and think things over", "I've still got the greatest enthusiasm and confidence in the mission. And I want to help you.", "it can only be attributable to human error"]
            random_msg(messages)
          end
    
          def random_positivism
            messages = ["The world is everything that is the case.", "What is the case (a fact) is the existence of states of affairs.", "A logical picture of facts is a thought.", "A thought is a proposition with sense.", "A proposition is a truth-function of elementary propositions.", "The general form of a proposition is the general form of a truth function.", "Whereof one cannot speak, one must pass over in silence."]
            random_msg(messages)
          end
    
          def random_msg(messages)
            the_msg = messages.sort_by {rand}.pop
            if the_msg.index("/")
              the_msg.gsub!("/", "")
              action channel, the_msg
            else
              msg channel, "#{nick}: #{the_msg}"
            end
          end
        end
      end
    end
  end
end