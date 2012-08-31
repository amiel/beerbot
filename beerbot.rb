require 'cinch'

class BeerBot
  def self.add_beer sender, recipient

  end

  def self.cash_in sender, recipient

  end

  def self.status nick
    'No one.'
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
    m.reply "Duly noted, #{m.user.nick}. You owe a delicious beverage to #{recipient}."

    BeerBot.add_beer m.user.nick, recipient
  end

  # Take one down
  on :message, /(\S*) (paid up|(bought.*(beer|drink|beverage))).*/i do |m|
    sender = m.message.match(/(\S*) (paid up|(bought.*(beer|drink|beverage))).*/i)[1]

    m.reply "Glad to see #{sender} isn't as much of a deadbeat as I thought."
    BeerBot.cash_in sender, recipient
  end

  # Pass it around
  on :message, /.*who owes me (beer|beverages|drink).*/i do |m|
    m.reply BeerBot.status m.user.nick
  end

  # Help
  on :message, /beerbot.*(help|que|wtf).*/i do |m|
    m.reply 'You officially decree you owe someone a frosty one by saying "I owe a beer to johnnyawesome" or "Whelp, I really owe huntersthompson a drink after that one."'
    m.reply 'If you\'ve gotten your drink, you can say "mrdudeman bought me a drink"'
    m.reply 'You can see who owes you drinks by saying "Who owes me drinks?"'
  end
end

bot.start
