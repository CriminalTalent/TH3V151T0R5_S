# commands/use_item_command.rb
# encoding: UTF-8

class UseItemCommand
  def initialize(sender, item_name, sheet_manager)
    @sender        = sender.to_s.gsub('@', '')
    @item_name     = item_name.to_s.strip
    @sheet_manager = sheet_manager
  end

  def execute
    user = @sheet_manager.find_user(@sender)
    return "@#{@sender} 등록되지 않은 계정입니다." unless user

    items = user[:items].split(',').map(&:strip).reject(&:empty?)
    idx   = items.index(@item_name)
    return "@#{@sender} 소지하고 있지 않은 아이템입니다: #{@item_name}" unless idx

    item = @sheet_manager.find_item(@item_name)
    if item && !item[:usable]
      return "@#{@sender} #{@item_name}은(는) 사용할 수 없는 아이템입니다."
    end

    items.delete_at(idx)
    @sheet_manager.update_user(@sender, { items: items.join(',') })

    use_message = item&.dig(:use_message).to_s.strip
    result = if use_message.include?('/')
               use_message.split('/').map(&:strip).reject(&:empty?).sample
             elsif !use_message.empty?
               use_message
             else
               "#{@item_name}을(를) 사용했습니다."
             end

    "@#{@sender} #{result}"
  end
end
