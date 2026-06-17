# commands/dice_command.rb
# encoding: UTF-8
# [6D], [20D], [100D], [주사위] 지원

class DiceCommand
  def self.run(mastodon_client, notification)
    content = clean_html(notification.dig('status', 'content') || '')
    sender  = notification.dig('account', 'acct') || ''
    status_id = notification.dig('status', 'id')

    sides = case content
            when /\[(\d+)D\]/i then $1.to_i
            when /\[주사위\]/    then 6
            else 6
            end

    if sides < 1 || sides > 100
      mastodon_client.post_status(
        "@#{sender} 면 수는 1~100 사이로 입력해요. 예: [6D], [100D]",
        reply_to_id: status_id, visibility: 'unlisted'
      )
      return
    end

    result = rand(1..sides)
    mastodon_client.post_status(
      "@#{sender} #{result}",
      reply_to_id: status_id, visibility: 'unlisted'
    )
  rescue => e
    puts "[DICE 오류] #{e.message}"
  end

  def self.clean_html(html)
    html.to_s.gsub(/<[^>]*>/, '').gsub('&nbsp;', ' ').strip
  end
end
