# commands/yn_command.rb
# encoding: UTF-8

class YnCommand
  # HTML 태그 제거
  def self.clean_html(html)
    html.to_s.gsub(/<[^>]*>/, '').gsub('&nbsp;', ' ').strip
  end

  # 메인 명령 처리
  def self.run(mastodon_client, notification)
    begin
      content_raw = notification.dig("status", "content") || ""
      acct_info   = notification["account"] || {}
      sender      = acct_info["acct"] || ""
      content     = clean_html(content_raw)

      # 명령 확인 → [YN]
      unless content =~ /\[YN\]/i
        reply_to_notification(
          mastodon_client, notification,
          "@#{sender} YN 명령 형식이 잘못되었어요. 예: [YN]"
        )
        return
      end

      # 랜덤 YES / NO (단답)
      result = ["YES", "NO"].sample

      text = "@#{sender} #{result}"

      reply_to_notification(mastodon_client, notification, text)

    rescue => e
      puts "[YN-ERROR] #{e.class} - #{e.message}"
      puts e.backtrace.first(3).join("\n  ↳ ")
    end
  end

  # Reply helper
  def self.reply_to_notification(mastodon_client, notification, text, visibility: "unlisted")
    return if text.nil? || text.to_s.strip.empty?

    status_id =
      if notification.is_a?(Hash)
        notification.dig("status", "id") || notification["id"]
      elsif notification.respond_to?(:status) && notification.status.respond_to?(:id)
        notification.status.id
      elsif notification.respond_to?(:id)
        notification.id
      else
        notification.to_s
      end

    mastodon_client.post_status(text, reply_to_id: status_id, visibility: visibility)
  end
end
