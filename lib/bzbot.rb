require 'rubygems'
require 'isaac/bot'
require 'xmlrpc/client'
require 'dm-core'
require 'dm-aggregates'
require 'dm-migrations'

class String
  def start_with?(str)
    !!(self =~ /^#{str}/)
  end
end

DataMapper.setup(:default, "sqlite://#{ENV['PWD']}/bzbot.db")

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

bzbot = Isaac::Bot.new do 
  MAX_RESULTS = 20
  
  configure do |c|
    c.nick = "bzbot-beta"
    c.server = "localhost"
    c.port = 26667
  end
  
  on :connect do
    join "#bzbot-beta"
    init_xmlrpc_bz
  end
  
  on :channel, /^bzbot[:,]{0,1} desc(ribe|)( |)([0-9]+)/ do
    record_log
    bzdesc = ""
  
    begin
      bug_id = match[2].to_i
      bugs = @xmlrpc_bz.call("Bug.search", {"bug_id"=>bug_id})["bugs"]
      if bugs.size == 1
        bzdesc = " (#{bugs[0]["short_desc"]})"
        msg channel, "#{nick}: BZ #{bug_id}:  #{bzdesc} https://bugzilla.redhat.com/show_bug.cgi?id=#{bug_id}"
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
    msg channel, "#{nick}: https://bugzilla.redhat.com/show_bug.cgi?id=#{match[2]}"
  end
  
  on :channel, /(uw#|gt)( |)([0-9]+)/i do
    record_log
    msg channel, "#{nick}: https://condor-wiki.cs.wisc.edu/index.cgi/tktview?tn=#{match[2]}"
  end
  
  on :channel, /^bzbot[:,]{0,1} help$/i do
    record_log
    msg nick, "I will respond to messages on the channel of the form BZ([0-9]+) or UW#([0-9]+) and sent back a link to the relevant BZ or gittrac ticket"
  end
  
  on :channel, /(bzbot[:,]{0,1}\s*(thanks|thx)(.*)|(thanks|thx)(,|)\s*bzbot(.*))/i do
    record_log
    random_welcome
  end
  
  on :channel, /bzbot\s*(rocks|rules|is cool|is great)/i do
    record_log
    random_happy
  end
  
  on :channel, /bzbot\s*(sucks|blows|is worse than gradware|is an embarrassment to Ruby hippies everywhere)/i do
    record_log
    random_sad
  end
  
  on :private, /^emote (.*?) on (#.*)$/ do
    record_log
    action match[1], match[0]
  end
  
  on :private, /^say (.*?) on (#.*)$/ do
    record_log
    msg match[1], match[0]
  end
  
  on :private, /^alias (.*?)=(.*)$/ do
    record_log
    begin
      a = Alias.all(:nick=>match[0])
      a[0].delete if a.size == 1
      Alias.create(:nick=>match[0], :email=>match[1])
      msg nick, "#{match[0]} is an alias for #{match[1]}@redhat.com"
    rescue Exception
      msg nick, "Sorry, I couldn't do that."
    end
  end

  on :channel, /^bzbot[:,]{0,1} apropos\s*(.*)$/ do
    record_log
    
    words = match[0].split
    bugs = {}
    
    begin
      words.each do |word|
        result = @xmlrpc_bz.call("Bug.search", "quicksearch"=>word, "product"=>"Red Hat Enterprise MRG")
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
      bug_url = "https://bugzilla.redhat.com/show_bug.cgi?id=#{bug_id}"
      msg channel, "#{nick}:  I found one related bug:  BZ #{bug_id}:  #{bug_desc} #{bug_url}"
    when 2..MAX_RESULTS
      msg channel, "#{nick}:  I found #{bzcount} related bugs; check your PM."
      dump_bugs_priv(nick, bugs)
    else
      msg channel, "#{nick}:  I found #{bzcount} related bugs but am unwilling to spam you; check your PM for the first #{MAX_RESULTS}."
      dump_bugs_priv(nick, bugs)
    end  
  end
  
  on :channel, /^bzbot[:,]{0,1} (.*?) is bored$/ do
    record_log
    bored(match[0])
  end

  on :channel, /^bzbot[:,]{0,1} (I'm|I am) bored$/i do
    record_log
    bored(nick.gsub(/^_/, ""))
  end
  
  on :channel, /^bzbot disconnect$/ do
    record log
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
      @xmlrpc_bz = XMLRPC::Client.new2("https://bugzilla.redhat.com/xmlrpc.cgi")
    end

    def bored(name)
      
      aliased_email, = Alias.all(:nick=>name)

      name = aliased_email.email if aliased_email

      begin
        bugs = @xmlrpc_bz.call("Bug.search", {"product"=>"Red Hat Enterprise MRG", "assigned_to"=>"#{name}@redhat.com", "bug_status"=>"ASSIGNED"})["bugs"]
        if bugs.size == 0
          msg channel, "#{nick}: I can't help with that, sorry."
        else
          bug = bugs.sort_by {rand}.pop
          short_desc = bug["short_desc"]
          bug_id = bug["bug_id"]
          msg channel, "#{nick}:  might I suggest \"#{short_desc}\"?  https://bugzilla.redhat.com/show_bug.cgi?id=#{bug_id}"
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
        bug_url = "https://bugzilla.redhat.com/show_bug.cgi?id=#{bug_id}"
        msg nick, "BZ #{bug_id}:  #{bug_desc}  #{bug_url}"
        counter = counter + 1
        break if counter == MAX_RESULTS
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
    
    def check_for_achievements(channel, nick, bugid)
      b_s = bugid.to_s
      b_i = bugid.to_i
      if b_s.reverse == b_s
        msg channel, "#{nick} has unlocked a new bzbot achievement:  A bug, a plan, a canal, paguba!"
      end
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

DataMapper.finalize
DataMapper.auto_upgrade!

bzbot.start