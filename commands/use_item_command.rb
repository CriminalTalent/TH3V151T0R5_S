# commands/use_item_command.rb
# encoding: UTF-8

class UseItemCommand
  # 고정 회복량 아이템: { 정규화된(공백 제거) 이름 => 회복량 }
  HEAL_ITEMS = {
    '위겐웰드물약' => 10,
    '디터니원액'   => 30,
    '수상한영약'   => 50
  }

  def initialize(sender, item_name, sheet_manager, mastodon_client, notification, target: nil)
    @sender = sender.to_s.gsub('@', '')
    @item_name = item_name.to_s.strip
    @sheet_manager = sheet_manager
    @mastodon_client = mastodon_client
    @notification = notification
    @target = target.to_s.strip.empty? ? nil : target.to_s.gsub('@', '').strip
  end

  def execute
    user = @sheet_manager.find_user(@sender)
    return safe_reply("@#{@sender} 등록되지 않은 계정입니다.") unless user

    items = user[:items].split(',').map(&:strip).reject(&:empty?)
    idx = items.index(@item_name)
    return safe_reply("@#{@sender} 소지하고 있지 않은 아이템입니다: #{@item_name}") unless idx

    item = @sheet_manager.find_item(@item_name)
    if item && !item[:usable]
      return safe_reply("@#{@sender} #{@item_name}은(는) 사용할 수 없는 아이템입니다.")
    end

    normalized_name = @item_name.gsub(' ', '')
    heal_amount = HEAL_ITEMS[normalized_name]

    if heal_amount
      return use_heal_item(items, idx, heal_amount)
    end

    use_general_item(items, idx, item)
  end

  private

  def use_heal_item(items, idx, heal_amount)
    recipient_id = @target || @sender
    recipient_stats = @sheet_manager.find_stats(recipient_id)
    unless recipient_stats
      return safe_reply("@#{@sender} 대상 계정(@#{recipient_id})이 등록되지 않았습니다.")
    end

    items.delete_at(idx)
    @sheet_manager.update_user(@sender, { items: items.join(',') })

    max_hp = recipient_stats[:health]
    cur_hp = recipient_stats[:current_health]
    new_hp = [cur_hp + heal_amount, max_hp].min
    @sheet_manager.update_stat(recipient_id, '현재건강', new_hp)

    if @target
      safe_reply("@#{@sender} #{@item_name}을(를) 사용해 @#{recipient_id}에게 사용했습니다.\n현재건강: #{cur_hp} → #{new_hp} (최대 #{max_hp})")
    else
      safe_reply("@#{@sender} #{@item_name}을(를) 사용했습니다.\n현재건강: #{cur_hp} → #{new_hp} (최대 #{max_hp})")
    end
  end

  def use_general_item(items, idx, item)
    items.delete_at(idx)

    use_message = item&.dig(:use_message)
    user = @sheet_manager.find_user(@sender)

    if use_message && !use_message.strip.empty?
      candidates = use_message.split(',').map(&:strip).reject(&:empty?)
      if candidates.length > 1
        result = candidates.sample
        credit_match = result.match(/^크레딧\+(\d+)$/)
        if credit_match
          gained_credits = credit_match[1].to_i
          current_credits = user[:credits].to_i
          new_credits = current_credits + gained_credits
          @sheet_manager.update_user(@sender, { items: items.join(','), credits: new_credits })
          return safe_reply("@#{@sender} #{@item_name}을(를) 사용했습니다.\n크레딧: #{current_credits} → #{new_credits} (+#{gained_credits})")
        else
          clean_name = extract_text(result)
          items << clean_name
          @sheet_manager.update_user(@sender, { items: items.join(',') })
          return process_result("@#{@sender} #{@item_name}을(를) 사용해 '#{clean_name}'을(를) 획득했습니다.", result)
        end
      else
        @sheet_manager.update_user(@sender, { items: items.join(',') })
        return process_result("@#{@sender} #{extract_text(use_message)}", use_message)
      end
    else
      @sheet_manager.update_user(@sender, { items: items.join(',') })
      safe_reply("@#{@sender} #{@item_name}을(를) 사용했습니다.")
    end
  end

  def extract_text(content)
    text = content.split(%r{https?://}).first.to_s
    text.sub(/[\(（]\s*\z/, '').strip
  end

  def process_result(text, content)
    url = content[%r{https?://[^\s\)\]（）】〉》]+}]
    media_ids = []
    if url
      begin
        media_id = @mastodon_client.upload_media_from_url(url, description: @item_name)
        media_ids << media_id if media_id
      rescue => e
        puts "[UseItem 이미지] #{e.message}"
      end
    end
    safe_reply(text, media_ids)
  end

  def safe_reply(text, media_ids = [])
    return if text.nil? || text.to_s.strip.empty?
    status_id = @notification.dig('status', 'id')
    return unless status_id
    @mastodon_client.post_status(text, reply_to_id: status_id, visibility: 'unlisted', media_ids: media_ids)
  rescue => e
    puts "[UseItem 응답] #{e.message}"
  end
end
