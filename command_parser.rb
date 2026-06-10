# command_parser.rb
# encoding: UTF-8
require 'cgi'

require_relative 'commands/enroll_command'
require_relative 'commands/buy_command'
require_relative 'commands/pouch_command'
require_relative 'commands/use_item_command'
require_relative 'commands/transfer_item_command'
require_relative 'commands/transfer_credits_command'
require_relative 'commands/stat_buy_command'

module CommandParser
  # 간단한 쿨다운 (같은 cmd를 30초 내 중복 응답 방지)
  COOLDOWNS  = {}
  COOLDOWN_S = 30

  def self.parse(mastodon_client, sheet_manager, notification)
    content_raw  = notification.dig('status', 'content') || ''
    account_info = notification['account'] || {}
    sender       = account_info['acct'] || ''
    content      = clean_html(content_raw)

    puts "[PARSER] @#{sender}: #{content}"

    message  = nil
    cmd_key  = nil

    case content

    # ── 등록 ──────────────────────────────────────
    when /\[등록\/(.+?)\]/
      name = $1.strip
      cmd_key = :enroll
      EnrollCommand.new(sheet_manager, mastodon_client, sender, name, notification['status']).execute
      return

    # ── 구매 ──────────────────────────────────────
    when /\[구매\/(.+?)\]/
      cmd_key = :buy
      message = BuyCommand.new(content, sender, sheet_manager).execute

    # ── 스탯 구매 ─────────────────────────────────
    when /\[스탯구매\/(.+?)\]/
      cmd_key = :stat_buy
      message = StatBuyCommand.new(content, sender, sheet_manager).execute

    # ── 소지품 ────────────────────────────────────
    when /\[소지품\]/
      cmd_key = :pouch
      PouchCommand.new(sender, sheet_manager, mastodon_client, notification).execute
      return

    # ── 사용 ──────────────────────────────────────
    when /\[사용\/(.+?)\]/
      item_name = $1.strip
      cmd_key = :use_item
      message = UseItemCommand.new(sender, item_name, sheet_manager).execute

    # ── 양도 (아이템) ─────────────────────────────
    when /\[양도\/(.+?)\/@(.+?)\]/
      item_name = $1.strip
      target    = $2.strip.split('@').first
      cmd_key = :transfer_item
      message = TransferItemCommand.new(sender, target, item_name, sheet_manager).execute

    # ── 양도 (크레딧) ─────────────────────────────
    when /\[송금\/(\d+)\/@(.+?)\]/
      amount = $1.to_i
      target = $2.strip.split('@').first
      cmd_key = :transfer_credits
      message = TransferCreditsCommand.new(sender, target, amount, sheet_manager).execute

    else
      puts "[PARSER] 인식되지 않은 명령어"
      return
    end

    safe_reply(mastodon_client, notification, sender, message, cmd_key: cmd_key) if message

  rescue => e
    puts "[PARSER 오류] #{e.class}: #{e.message}"
    puts e.backtrace.first(5).join("\n  ")
  end

  # ──────────────────────────────────────────────
  private

  def self.safe_reply(mastodon_client, notification, acct, text, cmd_key: :default, visibility: 'unlisted')
    return if text.nil? || text.to_s.strip.empty?

    status_id = notification.is_a?(Hash) ? notification.dig('status', 'id') : nil
    return unless status_id

    key = "#{acct}:#{cmd_key}"
    last = COOLDOWNS[key]
    if last && (Time.now - last) < COOLDOWN_S
      puts "[COOLDOWN] @#{acct} #{cmd_key} 스킵"
      return
    end
    COOLDOWNS[key] = Time.now

    mastodon_client.post_status(text, reply_to_id: status_id, visibility: visibility)
  rescue => e
    puts "[REPLY 오류] @#{acct}: #{e.message}"
  end

  def self.clean_html(html)
    return '' if html.nil?
    s = html.to_s
      .gsub(/<br\s*\/?>/i, "\n")
      .gsub(/<\/p\s*>/i, "\n")
      .gsub(/<p[^>]*>/i, '')
      .gsub(/<[^>]*>/, '')
    CGI.unescapeHTML(s).gsub("\u00A0", ' ').strip
  rescue
    html.to_s
  end
end
