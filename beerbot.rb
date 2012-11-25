if ENV["HEROKU_POSTGRESQL_AQUA_URL"]
  production = true
end

require 'cinch'
require 'data_mapper'
require 'dm-sqlite-adapter' unless production
require 'dm-postgres-adapter'
require 'i18n'

class BeerBot
  include DataMapper::Resource
  property :id, Serial
  property :sender, String
  property :recipient, String
  property :reason, String
  property :count, Integer, :default => 0

  def self.add_beer sender, recipient
    round = self.first_or_create(:sender => sender, :recipient => recipient)
    round.update(:count => round.count + 1)

    round.count
  end

  def self.cash_in sender, recipient
    round = self.first_or_create(:sender => sender, :recipient => recipient)
    return false unless round.count > 0
    round.update(:count => round.count - 1)

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

    if response == 'YES'
      'foul'
    else
      'good'
    end
  end
end


bot = Cinch::Bot.new do
  configure do |c|
    c.nick = "beerbot"
    c.server = "irc.oftc.net"
    #c.channels = ["#bhamruby", "#beerbot"]
    c.channels = ["#beerbot"]

    DRINKS = 'beer|drink|beverage|scotch|whiskey|martini'

    I18n.load_path = ['responses.yml']
    I18n.default_locale = BeerBot.mood
  end

  helpers do
    def quantity number
      if number == 0
        'none'
      elsif number == 1
        'one'
      else
        'many'
      end
    end
  end

  # Add a drink
  on :message, /.*i owe (\S*) a (#{DRINKS}).*/i do |m|

    recipient = m.message.match(/.*i owe (.*) a (#{DRINKS}).*/i)[1]
    round = BeerBot.add_beer m.user.nick, recipient
    m.reply I18n.t("add.#{quantity(round)}", :nick => m.user.nick, :round => round, :recipient => recipient)
  end

  # Take one down
  on :message, /(\S*) (paid up|(bought.*(#{DRINKS}))).*/i do |m|
    sender = m.message.match(/(\S*) (paid up|(bought.*(#{DRINKS}))).*/i)[1]

    round = BeerBot.cash_in sender, m.user.nick

    if round
      m.reply I18n.t("redeem.success")
    else
      m.reply I18n.t("redeem.failure")
    end
  end

  # Pass it around
  on :message, /.*who owes me.*(#{DRINKS}).*/i do |m|
    owed = BeerBot.owed m.user.nick

    if owed.size > 0
      m.reply owed.map{ |round| "#{round.sender} (#{round.count})"}.join(', ')
    else
      I18n.t("status.none")
    end
  end

  on :message, /.*who do i owe.*(#{DRINKS}).*/i do |m|
    owes = BeerBot.owes m.user.nick

    if owes.size > 0
      m.reply owes.map{ |round| "#{round.sender} (#{round.count})"}.join(', ')
    else
      m.reply I18n.t('owes.none')
    end
  end

  # Help
  on :message, /beerbot.*(help|que|wtf).*/i do |m|
    m.reply 'You officially decree you owe someone a frosty one by saying "I owe a beer to johnnyawesome" or "Whelp, I really owe huntersthompson a drink after that one."'
    m.reply 'If you have gotten your drink, you can say "mrdudeman bought me a drink"'
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
