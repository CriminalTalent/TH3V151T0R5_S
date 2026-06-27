# command_parser.rb
# encoding: UTF-8
require 'cgi'
require 'digest'
require_relative 'commands/enroll_command'
require_relative 'commands/buy_command'
require_relative 'commands/pouch_command'
require_relative 'commands/use_item_command'
require_relative 'commands/transfer_item_command'
require_relative 'commands/transfer_credits_command'
require_relative 'commands/stat_buy_command'
require_relative 'commands/tarot_command'
require_relative 'commands/bet_command'
require_relative 'commands/dice_command'
require_relative 'commands/coin_command'
require_relative 'commands/yn_command'
require_relative 'commands/hideout_command'
require_relative 'commands/combination_command'
require_relative 'commands/material_command'
module CommandParser
  COOLDOWNS  = {}
  COOLDOWN_S = 30
  def self.parse(mastodon_client, sheet_manager, notification)
    content_raw  = notification.dig('status', 'content') || ''
    sender       = notification.dig('account', 'acct') || ''
    content      = clean_html(content_raw)
    message  = nil
    cmd_key  = nil
    case content
    when /\[등록\/(.+?)\]/
      EnrollCommand.new(sheet_manager, mastodon_client, sender, $1.strip, notification['status']).execute
      return
    when /\[구매\/(.+?)\]/
      cmd_key = "buy:#{$1.strip}"
      message = BuyCommand.new(content, sender, sheet_manager).execute
    when /\[스탯구매\/(.+?)\]/
      cmd_key = "stat_buy:#{$1.strip}"
      message = StatBuyCommand.new(content, sender, sheet_manager).execute
    when /\[소지품\]/
      PouchCommand.new(sender, sheet_manager, mastodon_client, notification).execute
      return
    when /\[사용\/(.+?)\]/
      cmd_key = "use_item:#{$1.strip}"
      message = UseItemCommand.new(sender, $1.strip, sheet_manager).execute
    when /\[양도\/(\d+)\/@(.+?)\]/
      cmd_key = "transfer_credits:#{$1}:#{$2.strip}"
      message = TransferCreditsCommand.new(sender, $2.strip.split('@').first, $1.to_i, sheet_manager).execute
    when /\[양도\/([^@\/]+?)\/@(.+?)\]/
      cmd_key = "transfer_item:#{$1.strip}:#{$2.strip}"
      message = TransferItemCommand.new(sender, $2.strip.split('@').first, $1.strip, sheet_manager).execute
    when /\[타로\]/
      cmd_key = :tarot
      message = TarotCommand.new(sender, sheet_manager).execute
    when /\[베팅\/(\d+)\]/
      cmd_key = "bet:#{$1}"
      message = BetCommand.new(sender, $1.to_i, sheet_manager).execute
    when /\[은신처꾸미기\]/
      HideoutCommand.new(sender, sheet_manager, mastodon_client, notification).execute
      return
    when /\[조합\/(.+?)\/(.+?)\/(.+?)\]/
      cmd_key = "combination:#{$1.strip}:#{$2.strip}:#{$3.strip}"
      message = CombinationCommand.new(sender, $1.strip, $2.strip, $3.strip, sheet_manager).execute
    when /\[재료뽑기\]/
      cmd_key = :material
      message = MaterialCommand.new(sender, sheet_manager).execute
    when /\[(\d+)D\]/i, /\[주사위\]/
      DiceCommand.run(mastodon_client, notification)
      return
    when /\[동전\]/i
      CoinCommand.run(mastodon_client, notification)
      return
    when /\[YN\]/i
      YnCommand.run(mastodon_client, notification)
      return
    else
      return
    end
    safe_reply(mastodon_client, notification, sender, message, cmd_key: cmd_key) if message
  rescue => e
    puts "[PARSER 오류] #{e.class}: #{e.message}"
    puts e.backtrace.first(3).join("\n  ")
  end
  private
  def self.safe_reply(mastodon_client, notification, acct, text, cmd_key: :default)
    return if text.nil? || text.to_s.strip.empty?
    status_id = notification.dig('status', 'id')
    return unless status_id
    content_hash = Digest::MD5.hexdigest(text.to_s)[0, 8]
    key  = "#{acct}:#{cmd_key}:#{content_hash}"
    last = COOLDOWNS[key]
    if last && (Time.now - last) < COOLDOWN_S
      puts "[COOLDOWN] @#{acct} #{cmd_key} 스킵"
      return
    end
    COOLDOWNS[key] = Time.now
    mastodon_client.post_status(text, reply_to_id: status_id, visibility: 'unlisted')
  rescue => e
    puts "[REPLY 오류] @#{acct}: #{e.message}"
  end
  def self.clean_html(html)
    return '' if html.nil?
    CGI.unescapeHTML(
      html.to_s
        .gsub(/<br\s*\/?>/i, "\n")
        .gsub(/<\/p\s*>/i, "\n")
        .gsub(/<p[^>]*>/i, '')
        .gsub(/<[^>]*>/, '')
    ).gsub("\u00A0", ' ').strip
  rescue
    html.to_s
  end
end
