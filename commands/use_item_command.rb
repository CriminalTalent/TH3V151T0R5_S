# commands/use_item_command.rb
# encoding: UTF-8
class UseItemCommand
  WIGGENWELD_NAME = '위겐웰드물약'
  WIGGENWELD_HEAL = 5

  def initialize(sender, item_name, sheet_manager, mastodon_client, notification)
    @sender = sender.to_s.gsub('@', '')
    @item_name = item_name.to_s.strip
    @sheet_manager = sheet_manager
    @mastodon_client = mastodon_client
    @notification = notification
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

    items.delete_at(idx)

    if @item_name.gsub(' ', '') == WIGGENWELD_NAME
      @sheet_manager.update_user(@sender, { items: items.join(',') })
      stats = @sheet_manager.find_stats(@sender)
      if stats
        max_hp = stats[:health]
        cur_hp = stats[:current_health]
        new_hp = [cur_hp + WIGGENWELD_HEAL, max_hp].min
        @sheet_manager.update_stat(@sender, '현재건강', new_hp)
        return safe_reply("@#{@sender} #{@item_name}을(를) 사용했습니다.\n현재건강: #{cur_hp} → #{new_hp} (최대 #{max_hp})")
      end
    end

    use_message = item&.dig(:use_message)
    if use_message && !use_message.strip.empty?
      candidates = use_message.split(',').map(&:strip).reject(&:empty?)
      if candidates.length > 1
        result = candidates.sample
        items << result
        @sheet_manager.update_user(@sender, { items: items.join(',') })
        process_result("@#{@sender} #{@item_name}을(를) 사용해 '#{extract_text(result)}'을(를) 획득했습니다.", result)
      else
        @sheet_manager.update_user(@sender, { items: items.join(',') })
        process_result("@#{@sender} #{extract_text(use_message)}", use_message)
      end
    else
      @sheet_manager.update_user(@sender, { items: items.join(',') })
      safe_reply("@#{@sender} #{@item_name}을(를) 사용했습니다.")
    end
  end

  private

  def extract_text(content)
    content.split(%r{https?://}).first.strip
  end

  def process_result(text, content)
    url = content[%r{https?://\S+}]
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
