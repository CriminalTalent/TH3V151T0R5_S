# commands/buy_command.rb
# encoding: UTF-8

class BuyCommand
  def initialize(content, student_id, sheet_manager, mastodon_client, notification)
    @content         = content
    @student_id      = student_id.gsub('@', '')
    @sheet_manager   = sheet_manager
    @mastodon_client = mastodon_client
    @notification    = notification
    match = content.match(/\[구매\/(.+?)\]/)
    @raw_items = match ? match[1] : nil
  end

  def execute
    status_id = @notification.dig('status', 'id')

    unless @raw_items
      reply("구매 형식이 잘못되었습니다. 예: [구매/아이템명]", status_id)
      return
    end

    item_names = @raw_items.split(',').map(&:strip).reject(&:empty?)

    if item_names.empty?
      reply("구매 형식이 잘못되었습니다. 예: [구매/아이템명]", status_id)
      return
    end

    if item_names.length == 1
      return execute_single(item_names.first, status_id)
    end

    execute_multi(item_names, status_id)
  end

  private

  # ---------------- 단일 아이템 구매 (기존 동작 그대로) ----------------
  def execute_single(item_name, status_id)
    player = @sheet_manager.find_user(@student_id)
    unless player
      reply("등록되지 않은 계정입니다.", status_id)
      return
    end

    item = @sheet_manager.find_item(item_name)
    unless item
      reply("#{item_name} 아이템을 찾을 수 없습니다.", status_id)
      return
    end

    unless item[:sellable]
      reply("#{item_name}은(는) 현재 판매하지 않는 아이템입니다.", status_id)
      return
    end

    price = item[:price]
    if player[:credits] < price
      reply("크레딧이 부족합니다. 현재 #{player[:credits]}크레딧, 필요 #{price}크레딧.", status_id)
      return
    end

    new_credits = player[:credits] - price
    inventory   = player[:items].split(',').map(&:strip).reject(&:empty?)
    inventory << item_name
    new_items = inventory.join(',')

    @sheet_manager.update_user(@student_id, {
      credits: new_credits,
      items:   new_items
    })

    puts "[구매] @#{@student_id} #{item_name} #{price}크레딧"

    media_ids = []
    image_url = item[:image_url].to_s.strip
    unless image_url.empty?
      media_id = @mastodon_client.upload_media_from_url(image_url, description: item_name)
      media_ids << media_id if media_id
    end

    reply(
      "#{item_name}을(를) #{price}크레딧에 구매했습니다. 잔여 크레딧: #{new_credits}크레딧.",
      status_id,
      media_ids
    )
  end

  # ---------------- 다중 아이템 구매 ----------------
  def execute_multi(item_names, status_id)
    player = @sheet_manager.find_user(@student_id)
    unless player
      reply("등록되지 않은 계정입니다.", status_id)
      return
    end

    items_data = []

    item_names.each do |name|
      item = @sheet_manager.find_item(name)
      unless item
        reply("#{name} 아이템을 찾을 수 없습니다.", status_id)
        return
      end

      unless item[:sellable]
        reply("#{name}은(는) 현재 판매하지 않는 아이템입니다.", status_id)
        return
      end

      items_data << item
    end

    total_price = items_data.sum { |item| item[:price] }

    if player[:credits] < total_price
      reply("크레딧이 부족합니다. 현재 #{player[:credits]}크레딧, 필요 #{total_price}크레딧.", status_id)
      return
    end

    new_credits = player[:credits] - total_price
    inventory   = player[:items].split(',').map(&:strip).reject(&:empty?)
    inventory.concat(item_names)
    new_items = inventory.join(',')

    @sheet_manager.update_user(@student_id, {
      credits: new_credits,
      items:   new_items
    })

    puts "[구매] @#{@student_id} #{item_names.join(',')} #{total_price}크레딧"

    media_ids = []
    items_data.each_with_index do |item, index|
      image_url = item[:image_url].to_s.strip
      next if image_url.empty?

      media_id = @mastodon_client.upload_media_from_url(image_url, description: item_names[index])
      media_ids << media_id if media_id
    end

    item_lines = item_names.each_with_index.map do |name, index|
      "#{name} (#{items_data[index][:price]}크레딧)"
    end

    text = "다음 아이템을 구매했습니다.\n" \
      "#{item_lines.join("\n")}\n" \
      "총 #{total_price}크레딧 사용. 잔여 크레딧: #{new_credits}크레딧."

    reply(text, status_id, media_ids.first(4))
  end

  def reply(text, status_id, media_ids = [])
    @mastodon_client.post_status(
      "@#{@student_id} #{text}",
      reply_to_id: status_id,
      visibility: 'unlisted',
      media_ids: media_ids
    )
  end
end
