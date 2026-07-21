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
    @item_name = match ? match[1].strip : nil
  end

  def execute
    status_id = @notification.dig('status', 'id')

    unless @item_name
      reply("구매 형식이 잘못되었습니다. 예: [구매/아이템명]", status_id)
      return
    end

    player = @sheet_manager.find_user(@student_id)
    unless player
      reply("등록되지 않은 계정입니다.", status_id)
      return
    end

    item = @sheet_manager.find_item(@item_name)
    unless item
      reply("#{@item_name} 아이템을 찾을 수 없습니다.", status_id)
      return
    end

    unless item[:sellable]
      reply("#{@item_name}은(는) 현재 판매하지 않는 아이템입니다.", status_id)
      return
    end

    price = item[:price]
    if player[:credits] < price
      reply("크레딧이 부족합니다. 현재 #{player[:credits]}크레딧, 필요 #{price}크레딧.", status_id)
      return
    end

    new_credits = player[:credits] - price
    inventory   = player[:items].split(',').map(&:strip).reject(&:empty?)
    inventory << @item_name
    new_items = inventory.join(',')

    @sheet_manager.update_user(@student_id, {
      credits: new_credits,
      items:   new_items
    })

    puts "[구매] @#{@student_id} #{@item_name} #{price}크레딧"

    media_ids = []
    image_url = item[:image_url].to_s.strip
    unless image_url.empty?
      media_id = @mastodon_client.upload_media_from_url(image_url, description: @item_name)
      media_ids << media_id if media_id
    end

    reply(
      "#{@item_name}을(를) #{price}크레딧에 구매했습니다. 잔여 크레딧: #{new_credits}크레딧.",
      status_id,
      media_ids
    )
  end

  private

  def reply(text, status_id, media_ids = [])
    @mastodon_client.post_status(
      "@#{@student_id} #{text}",
      reply_to_id: status_id,
      visibility: 'unlisted',
      media_ids: media_ids
    )
  end
end
