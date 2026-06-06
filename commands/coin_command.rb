# commands/coin_command.rb
# encoding: UTF-8

class CoinCommand
  # HTML 태그 제거 유틸
  def self.clean_html(html)
    html.to_s.gsub(/<[^>]*>/, '').gsub('&nbsp;', ' ').strip
  end

  # 메인 엔트리 포인트
  def self.run(mastodon_client, notification)
    begin
      content_raw  = notification.dig("status", "content") || ""
      acct_info    = notification["account"] || {}
      sender_acct  = acct_info["acct"] || ""
      content      = clean_html(content_raw)

      # 명령 인식: [동전], [coin], [COIN], [Coin]
      unless content =~ /\[(동전|coin)\]/i
        reply_to_notification(
          mastodon_client,
          notification,
          "@#{sender_acct} 동전 명령 형식이 잘못되었어요. 예: [동전]"
        )
        return
      end

      # 50:50 랜덤
      result = ["앞면", "뒷면"].sample

      # 메시지 (RP 톤)
      text = "@#{sender_acct} 동전을 손가락으로 툭~ 하고 튕겼어요.\n" \
             "결과는… #{result}이네요!"

      reply_to_notification(mastodon_client, notification, text)

    rescue => e
      puts "[COIN-ERROR] #{e.class} - #{e.message}"
      puts e.backtrace.first(3).join("\n  ↳ ")
    end
  end

  # Mastodon reply helper
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
