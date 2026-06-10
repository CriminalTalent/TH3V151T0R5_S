# commands/pouch_command.rb
# encoding: UTF-8

class PouchCommand
  def initialize(sender, sheet_manager, mastodon_client, notification)
    @sender          = sender.to_s.gsub('@', '')
    @sheet_manager   = sheet_manager
    @mastodon_client = mastodon_client
    @notification    = notification
  end

  def execute
    status_id = @notification.dig('status', 'id')

    user  = @sheet_manager.find_user(@sender)
    stats = @sheet_manager.find_stats(@sender)

    unless user
      @mastodon_client.post_status(
        "@#{@sender} 등록되지 않은 계정입니다.",
        reply_to_id: status_id,
        visibility: 'unlisted'
      )
      return
    end

    items = user[:items].split(',').map(&:strip).reject(&:empty?)

    lines = []
    lines << "@#{@sender}"
    lines << "──────────────────"
    lines << "#{user[:name]}의 소지품"
    lines << "──────────────────"
    lines << "크레딧: #{user[:credits]}C"
    lines << "스탯 포인트 잔여: #{user[:stat_points]}pt"
    lines << ""

    if stats
      lines << "[스탯]"
      lines << "건강(체력): #{stats[:health]}"
      lines << "마법능력(공격): #{stats[:magic]}"
      lines << "인내(방어): #{stats[:endurance]}"
      lines << "속도(민첩): #{stats[:speed]}"
      lines << "기술(명중): #{stats[:skill]}"
      lines << "행운(크리티컬): #{stats[:luck]}"
      lines << ""
    end

    if items.any?
      lines << "[아이템]"
      items.each { |it| lines << "- #{it}" }
    else
      lines << "[아이템] 없음"
    end

    lines << "──────────────────"

    @mastodon_client.post_status(
      lines.join("\n"),
      reply_to_id: status_id,
      visibility: 'unlisted'
    )
  end
end
