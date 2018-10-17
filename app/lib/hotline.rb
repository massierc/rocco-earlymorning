class Hotline
  attr_reader :admins, :requestor
  attr_accessor :recipient, :message

  def initialize(requestor, *args)
    @bot = Telegram.bot
    @admins = %w(gildof massierc)
    @requestor = User.find_by_username(requestor)
    case args.length
    when 0 then nil
    when 1 then @recipient = args[0]
    else
      @recipient = args[0]
      @message = args.drop(1).join(' ')
    end
  end

  def send_message
    recipients = get_recipient_group
    if recipients.length > 0
      recipients.each do |r|
        @bot.send_message(chat_id: r.uid, text: message, parse_mode: 'markdown' )
      end
      conf_msg = "✉️ messaggio inviato a #{recipients.length > 1 ? "(#{recipients.length} utenti)" : @recipient}."
      @bot.send_message(chat_id: @requestor.uid, text: conf_msg)
    else
      @bot.send_message(chat_id: @requestor.uid, text: "❌ non trovo nessun utente o gruppo chiamato #{@recipient}, riprova!")
    end
  end

  def get_recipient_group
    case @recipient
    when 'emf'
      @message.prepend("`✉️ messaggio per EMF:` ")
      User.where(company_id: 0)
    when 'em'
      @message.prepend("`✉️ messaggio per EM:` ")
      User.where(company_id: 1)
    when 'all'
      @message.prepend("`✉️ messaggio global:` ")
      User.where(company_id: [0, 1])
    else
      Rails.env.production?
      ? User.where("name ILIKE :query OR username ILIKE :query", query: "%#{@recipient}%")
      : User.where("name LIKE :query OR username LIKE :query", query: "%#{@recipient.downcase}%")
    end
  end

  def is_valid?
    @admins.include? @requestor.username
  end

  def status
    if @recipient && @message
      'complete'
    elsif @recipient
      'message_missing'
    else
      'empty'
    end
  end
end