# commands/special_doll_command.rb
# 특별한 인형 뽑기 - 50갈레온 차감 + 이미지 첨부 + 사용자 지급

class SpecialDollCommand
  PRICE = 50

  def self.run(mastodon_client, sheet_manager, notification)
    begin
      account_info = notification["account"] || {}
      raw_sender   = account_info["acct"].to_s
      sender       = raw_sender.split('@').first
      status_id    = notification.dig("status", "id")

      unless status_id
        puts "[DOLL] ERROR: status_id를 찾을 수 없음"
        return
      end

      puts "[DOLL] 명령 실행: @#{sender}"

      # 1. 사용자 확인
      player = sheet_manager.find_user(sender)
      unless player
        mastodon_client.post_status(
          "@#{sender} 먼저 입학해주세요.",
          reply_to_id: status_id,
          visibility: "unlisted"
        )
        return
      end

      current_galleons = player[:galleons].to_i

      # 2. 갈레온 체크
      if current_galleons < PRICE
        mastodon_client.post_status(
          "@#{sender} 갈레온이 부족합니다. (필요: #{PRICE}G)",
          reply_to_id: status_id,
          visibility: "unlisted"
        )
        return
      end

      # 3. 랜덤 인형 가져오기
      doll = sheet_manager.get_random_doll
      unless doll
        mastodon_client.post_status(
          "인형 상자가 비어있거나 오류가 발생했습니다.",
          reply_to_id: status_id,
          visibility: "unlisted"
        )
        return
      end

      doll_name = doll[:name].to_s
      image_url = doll[:image_url].to_s

      puts "[DOLL] 선택된 인형: #{doll_name}"
      puts "[DOLL] 이미지 URL: #{image_url}"

      # 4. 인벤토리 + 갈레온 계산 (※ 아직 시트 반영 전)
      current_items = player[:items].to_s
        .split(',')
        .map(&:strip)
        .reject(&:empty?)

      current_items << doll_name
      new_galleons = current_galleons - PRICE

      # 5. 시트 업데이트 (★ 가장 중요: 한 번에)
      sheet_manager.update_user(
        sender,
        galleons: new_galleons,
        items: current_items.join(',')
      )

      # 6. 이미지 업로드
      media_id = mastodon_client.upload_media_from_url(
        image_url,
        description: doll_name
      )

      unless media_id
        mastodon_client.post_status(
          "@#{sender} 인형은 지급되었으나 이미지 업로드에 실패했습니다.",
          reply_to_id: status_id,
          visibility: "unlisted"
        )
        return
      end

      puts "[DOLL] 이미지 업로드 성공: #{media_id}"

      # 7. 답글 전송
      message = <<~MSG
        @#{sender}
        특별한 인형을 구매했습니다!
        - 인형: #{doll_name}
        - 가격: #{PRICE}G
        - 잔액: #{new_galleons}G
      MSG

      mastodon_client.post_status(
        message.strip,
        reply_to_id: status_id,
        visibility: "unlisted",
        media_ids: [media_id]
      )

      puts "[DOLL] 지급 완료: #{doll_name}"

    rescue => e
      puts "[DOLL 오류] #{e.class}: #{e.message}"
      puts e.backtrace.first(5).join("\n  ↳ ")

      begin
        if status_id
          mastodon_client.post_status(
            "인형을 꺼내는 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.",
            reply_to_id: status_id,
            visibility: "unlisted"
          )
        end
      rescue
        puts "[DOLL] 오류 메시지 전송 실패"
      end
    end
  end
end
