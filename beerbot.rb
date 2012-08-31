require 'cinch'
require 'data_mapper'
#require 'dm-sqlite-adapter'
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

  def self.status nick
    return self.all(:recipient => nick, :count.gt => 0)
  end
end

bot = Cinch::Bot.new do
  configure do |c|
    c.nick = "beerbot"
    c.server = "irc.oftc.net"
    c.channels = ["#bhamruby"]
  end

  # Add a drink
  on :message, /.*i owe (\S*) a (beer|drink).*/i do |m|
    recipient = m.message.match(/.*i owe (.*) a (beer|drink|beverage).*/i)[1]

    round = BeerBot.add_beer m.user.nick, recipient

    if round > 1
      m.reply "Got it, #{m.user.nick}. You owe a #{round} drinks to #{recipient}. Better get buying."
    else
      m.reply "Duly noted, #{m.user.nick}. You owe a delicious beverage to #{recipient}."
    end
  end

  # Take one down
  on :message, /(\S*) (paid up|(bought.*(beer|drink|beverage))).*/i do |m|
    sender = m.message.match(/(\S*) (paid up|(bought.*(beer|drink|beverage))).*/i)[1]

    round = BeerBot.cash_in sender, m.user.nick

    if round
      m.reply "Glad to see #{sender} isn't as much of a deadbeat as I thought."
    else
      m.reply "Well this is awkward. #{sender} didn't owe you anything. Poor lifestyle choices all around."
    end
  end

  # Pass it around
  on :message, /.*who owes me.*(beer|beverages|drink).*/i do |m|
    status = BeerBot.status m.user.nick

    if status.size > 0
      m.reply status.map{ |round| "#{round.sender} (#{round.count})"}.join(', ')
    else
      m.reply 'No one owes you beer. You should really be nicer to people.'
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

DataMapper.setup(:default, (ENV["HEROKU_POSTGRESQL_AQUA_URL"] || "sqlite3:///#{Dir.pwd}/development.sqlite3"))
DataMapper.auto_upgrade!

bot.start
