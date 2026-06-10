# commands/buy_command.rb
# encoding: UTF-8

class BuyCommand
  def initialize(content, student_id, sheet_manager)
    @content    = content
    @student_id = student_id.gsub('@', '')
    @sheet_manager = sheet_manager
    match = content.match(/\[구매\/(.+?)\]/)
    @item_name = match ? match[1].strip : nil
  end

  def execute
    return "@#{@student_id} 구매 형식이 잘못되었습니다. 예: [구매/아이템명]" unless @item_name

    player = @sheet_manager.find_user(@student_id)
    return "@#{@student_id} 등록되지 않은 계정입니다." unless player

    item = @sheet_manager.find_item(@item_name)
    return "@#{@student_id} #{@item_name} 아이템을 찾을 수 없습니다." unless item

    unless item[:sellable]
      return "@#{@student_id} #{@item_name}은(는) 현재 판매하지 않는 아이템입니다."
    end

    price = item[:price]
    if player[:credits] < price
      return "@#{@student_id} 크레딧이 부족합니다. 현재 #{player[:credits]}크레딧, 필요 #{price}크레딧."
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
    "@#{@student_id} #{@item_name}을(를) #{price}크레딧에 구매했습니다. 잔여 크레딧: #{new_credits}크레딧."
  end
end
