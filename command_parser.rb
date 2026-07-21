# command_parser.rb
# encoding: UTF-8
require 'cgi'
require 'digest'
require_relative 'commands/enroll_command'
require_relative 'commands/buy_command'
require_relative 'commands/pouch_command'
require_relative 'commands/use_item_command'
require_relative 'commands/donation_command'
require_relative 'commands/transfer_item_command'
require_relative 'commands/transfer_credits_command'
require_relative 'commands/stat_buy_command'
require_relative 'commands/tarot_command'
require_relative 'commands/bet_command'
require_relative 'commands/dice_command'
require_relative 'commands/coin_command'
require_relative 'commands/yn_command'
require_relative 'commands/material_command'
require_relative 'commands/homestead_command'
require_relative 'commands/recipe_command'
require_relative 'commands/junk_command'

module CommandParser
  PROCESSED       = {}
  PROCESSED_TTL_S = 3600

  def self.parse(mastodon_client, sheet_manager, notification)
    content_raw  = notification.dig('status', 'content') || ''
    sender       = notification.dig('account', 'acct') || ''
    status_id    = notification.dig('status', 'id')
    content      = clean_html(content_raw)
    puts "[DEBUG] cleaned content: #{content.inspect}"

    if status_id
      cleanup_processed
      if PROCESSED[status_id]
        puts "[SKIP] 이미 처리된 status_id=#{status_id}"
        return
      end
      PROCESSED[status_id] = Time.now
    end

    message = nil

    case content
    when /\[등록\/(.+?)\]/
      EnrollCommand.new(sheet_manager, mastodon_client, sender, $1.strip, notification['status']).execute
      return
    when /\[구매\/(.+?)\]/
      BuyCommand.new(content, sender, sheet_manager, mastodon_client, notification).execute
      return
    when /\[스탯구매\/(.+?)\]/
      message = StatBuyCommand.new(content, sender, sheet_manager).execute
    when /\[소지품\]/
      PouchCommand.new(sender, sheet_manager, mastodon_client, notification).execute
      return
    when /\[기부\/(\d+)\]/
      message = DonationCommand.new(sender, $1.to_i, sheet_manager).execute
    when /\[사용\/(.+?)\]/
      UseItemCommand.new(sender, $1.strip, sheet_manager, mastodon_client, notification).execute
      return
    when /\[양도\/(\d+)\/@(.+?)\]/
      message = TransferCreditsCommand.new(sender, $2.strip.split('@').first, $1.to_i, sheet_manager).execute
    when /\[양도\/([^@\/]+?)\/@(.+?)\]/
      message = TransferItemCommand.new(sender, $2.strip.split('@').first, $1.strip, sheet_manager).execute
    when /\[수정구\]/, /\[타로\]/
      message = TarotCommand.new(sender, sheet_manager).execute
    when /\[베팅\/(\d+)\]/
      message = BetCommand.new(sender, $1.to_i, sheet_manager).execute
    when /\[잡동사니\]/
      message = JunkCommand.new(content, sender, sheet_manager).execute
    when /\[재료뽑기\]/
      message = MaterialCommand.new(content, sender, sheet_manager).execute
    when /\[은신처꾸미기\]/
      message = HomesteadCommand.new(content, sender, sheet_manager).execute
    when /\[조합\/(.+?)\/(.+?)\/(.+?)\]/
      message = RecipeCommand.new(content, sender, sheet_manager).execute
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

    safe_reply(mastodon_client, notification, sender, message) if message
  rescue => e
    puts "[PARSER 오류] #{e.class}: #{e.message}"
    puts e.backtrace.first(3).join("\n  ")
  end

  private

  def self.safe_reply(mastodon_client, notification, acct, text)
    return if text.nil? || text.to_s.strip.empty?

    status_id = notification.dig('status', 'id')
    return unless status_id

    mastodon_client.post_status(text, reply_to_id: status_id, visibility: 'unlisted')
  rescue => e
    puts "[REPLY 오류] @#{acct}: #{e.message}"
  end

  def self.cleanup_processed
    now = Time.now
    PROCESSED.delete_if { |_, t| (now - t) > PROCESSED_TTL_S }
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
