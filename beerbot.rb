if ENV["HEROKU_POSTGRESQL_AQUA_URL"]
  production = true
end

require 'cinch'
require 'data_mapper'
require 'dm-sqlite-adapter' unless production
require 'dm-postgres-adapter'

class BeerBot
  include DataMapper::Resource
  property :id, Integer, serial: true
  property :sender, String
  property :recipient, String
  property :count, Integer, default: 0

  def self.add_beer sender, recipient
    round = self.first_or_create(sender: sender, recipient: recipient)
    round.update(count: round.count + 1)

    round.count
  end

  def self.cash_in sender, recipient
    round = self.first_or_create(sender: sender, recipient: recipient)
    return false unless round.count > 0
    round.update(count: round.count - 1)

    round.count
  end

  def self.owed nick
    return self.all(:recipient => nick, :count.gt => 0)
  end

  def self.owes nick
    return self.all(:sender => nick, :count.gt => 0)
  end

  def self.mood
    require 'nokogiri'
    require 'open-uri'

    doc = Nokogiri::HTML(open('http://umbrellatoday.com/locations/240045947/forecast'))

    response = doc.css('section.content h3 span').first.content
    puts response

    if response == 'YES'
      'foul'
    else
      'good'
    end
  end
end

mood = BeerBot.mood

bot = Cinch::Bot.new do
  configure do |c|
    c.nick = "beerbot"
    c.server = "irc.oftc.net"
    c.channels = ["#bhamruby", "#beerbot"]
  end

  # Add a drink
  on :message, /.*i owe (\S*) a (beer|drink).*/i do |m|
    recipient = m.message.match(/.*i owe (.*) a (beer|drink|beverage).*/i)[1]

    round = BeerBot.add_beer m.user.nick, recipient

    if round > 1
      m.reply "Got it, #{m.user.nick}. You owe a #{round} drinks to #{recipient}. Better get buying." if mood == 'good'
      m.reply "Fine, #{m.user.nick}. You owe a #{round} drinks to #{recipient}. Dumbass." if mood == 'foul'
    else
      m.reply "Duly noted, #{m.user.nick}. You owe a delicious beverage to #{recipient}." if mood == 'good'
      m.reply "Not sure what #{recipient} did to deserve it, but you better pay up, #{m.user.nick}. I hate you both." if mood == 'foul'
    end
  end

  # Take one down
  on :message, /(\S*) (paid up|(bought.*(beer|drink|beverage))).*/i do |m|
    sender = m.message.match(/(\S*) (paid up|(bought.*(beer|drink|beverage))).*/i)[1]

    round = BeerBot.cash_in sender, m.user.nick

    if round
      m.reply "Glad to see #{sender} isn't as much of a deadbeat as I thought." if mood == 'good'
      m.reply "Hopefully that drink numbed the crushing emotional pain of being you, #{m.user.nick}." if mood == 'foul'
    else
      m.reply "Well this is awkward. #{sender} didn't owe you anything. We all make mistakes." if mood == 'good'
      m.reply "What the hell is wrong with you people. #{sender} didn't owe you fuckall. Poor lifestyle choices all around." if mood == 'foul'
    end
  end

  # Pass it around
  on :message, /.*who owes me.*(beer|beverages|drink).*/i do |m|
    owed = BeerBot.owed m.user.nick

    if owed.size > 0
      m.reply owed.map{ |round| "#{round.sender} (#{round.count})"}.join(', ')
    else
      m.reply 'No one owes you beer. You should really be nicer to people.' if mood == 'good'
      m.reply 'No one owes you beer, and no one likes you. You\'ll die alone.' if mood == 'foul'
    end
  end

  on :message, /.*who do i owe.*(beer|beverages|drink).*/i do |m|
    owes = BeerBot.owes m.user.nick

    if owes.size > 0
      m.reply owes.map{ |round| "#{round.sender} (#{round.count})"}.join(', ')
    else
      m.reply 'You don\'t owe anyone a beverage. Maybe you should share more.' if mood == 'good'
      m.reply 'No one. As it should be.' if mood == 'foul'
    end
  end

  # Help
  on :message, /beerbot.*(help|que|wtf).*/i do |m|
    m.reply 'You officially decree you owe someone a frosty one by saying "I owe a beer to johnnyawesome" or "Whelp, I really owe huntersthompson a drink after that one."'
    m.reply 'If you\'ve gotten your drink, you can say "mrdudeman bought me a drink"'
    m.reply 'You can see who owes you drinks by saying "Who owes me drinks?"'
  end
end


# Initialization
DataMapper.finalize

if production
  DataMapper.setup(:default, ENV["HEROKU_POSTGRESQL_AQUA_URL"])
else
  DataMapper.setup(:default, "sqlite3:///#{Dir.pwd}/development.sqlite3")
end

DataMapper.auto_upgrade!

bot.start
