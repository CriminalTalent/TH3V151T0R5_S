# commands/pouch_command.rb
# encoding: UTF-8

class PouchCommand
  BAR_WIDTH = 10

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

    if stats
      max_hp = stats[:health]
      cur_hp = stats[:current_health]
      lines << "건강: #{cur_hp}/#{max_hp}"
      lines << "[#{health_bar(cur_hp, max_hp)}]"
    end

    if items.any?
      grouped = items.tally.map do |name, count|
        count > 1 ? "#{name} x#{count}" : name
      end
      lines << "[아이템]"
      lines << grouped.join(', ')
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

  private

  def health_bar(cur, max, width = BAR_WIDTH)
    max = 1 if max.to_i <= 0
    filled = ((cur.to_f / max) * width).round
    filled = 0 if filled < 0
    filled = width if filled > width
    "█" * filled + "░" * (width - filled)
  end
end
