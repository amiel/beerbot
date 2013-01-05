require 'cinch'
require 'data_mapper'
require 'dm-postgres-adapter'
require 'i18n'
require 'nokogiri'
require 'open-uri'

class BeerBot
  include DataMapper::Resource
  property :id, Serial
  property :sender, String
  property :recipient, String
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
    doc = Nokogiri::HTML(open('http://umbrellatoday.com/locations/240045947/forecast'))

    response = doc.css('section.content h3 span').first.content
    response == "YES" ? 'foul' : 'good'
  end
end


bot = Cinch::Bot.new do
  configure do |c|
    c.nick = "beerbot"
    c.server = "irc.oftc.net"
    c.channels = ["#bhamruby"]

    DRINKS = 'beer|pint|drink|beverage|scotch|whiskey|martini'

    I18n.load_path = ['responses.yml']
    
    # I would call update_mood here, but I don't know if helpers are available,
    # and I'm not testing this pull-request :P
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

    def reply_with_list list, fallback
      if list.size > 0
        list.map{ |round| "#{round.sender} (#{round.count})"}.join(', ')
      else
        fallback
      end
    end
    
    def update_mood
      I18n.default_locale = BeerBot.mood
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
      m.reply I18n.t("redeem.success", :sender => sender)
    else
      m.reply I18n.t("redeem.failure", :sender => sender)
    end
  end

  # Pass it around
  on :message, /.*who owes me.*(#{DRINKS}).*/i do |m|
    owed = BeerBot.owed m.user.nick
    m.reply reply_with_list(owed, I18n.t("status.none"))
  end

  on :message, /.*who do i owe.*(#{DRINKS}).*/i do |m|
    owes = BeerBot.owes m.user.nick
    m.reply reply_with_list(owes, I18n.t("owes.none"))
  end

  # Help
  on :message, /beerbot.*(help|que|wtf).*/i do |m|
    m.reply 'You officially decree you owe someone a frosty one by saying "I owe a beer to johnnyawesome" or "Whelp, I really owe huntersthompson a drink after that one."'
    m.reply 'If you have gotten your drink, you can say "mrdudeman bought me a drink"'
    m.reply 'You can see who owes you drinks by saying "Who owes me drinks?"'
  end
  
  on :message, /beerbot.*update.*/i do |m|
    update_mood
  end
end

# Initialization
DataMapper.finalize
DataMapper.setup(:default, ENV["HEROKU_POSTGRESQL_AQUA_URL"])
DataMapper.auto_upgrade!

bot.start
