# commands/dice_command.rb
# encoding: UTF-8

class DiceCommand
  # HTML 태그 제거용 간단 유틸
  def self.clean_html(html)
    html.to_s.gsub(/<[^>]*>/, '').gsub('&nbsp;', ' ').strip
  end

  # 메인 진입점: CommandParser에서 호출
  def self.run(mastodon_client, notification)
    begin
      content_raw  = notification.dig("status", "content") || ""
      acct_info    = notification["account"] || {}
      sender_acct  = acct_info["acct"] || ""
      content      = clean_html(content_raw)

      # ----- 명령 파싱 -----
      dice_count = 1
      dice_sides = 6

      case content
      when /\[(\d+)D\]/i
        # [100D] 형식
        dice_sides = $1.to_i
        dice_count = 1
      when /\[주사위\]/i
        dice_count = 1
        dice_sides = 6
      when /\[d(\d+)\]/i
        dice_sides = $1.to_i
        dice_count = 1
      when /\[(\d+)d\]/i
        dice_sides = $1.to_i
        dice_count = 1
      else
        # 여기에 들어오면 잘못된 형식
        text = "@#{sender_acct} 주사위 형식을 이해하지 못했어요. 예: [주사위], [6D], [100D]"
        reply_to_notification(mastodon_client, notification, text)
        return
      end

      # 방어적 제한 (너무 큰 수 방지)
      if dice_sides <= 0 || dice_sides > 100
        text = "@#{sender_acct} 그 정도 면수는 좀 무리인데… 1~100 사이로 굴려줘요."
        reply_to_notification(mastodon_client, notification, text)
        return
      end

      # ----- 주사위 굴리기 -----
      result = rand(1..dice_sides)

      # ----- 결과: 멘션 + 숫자만 출력 -----
      text = "@#{sender_acct} #{result}"

      reply_to_notification(mastodon_client, notification, text)

    rescue => e
      puts "[DICE-ERROR] #{e.class} - #{e.message}"
      puts e.backtrace.first(3).join("\n  ↳ ")
    end
  end

  # 실제 답글 전송 헬퍼
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
