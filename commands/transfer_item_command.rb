# commands/transfer_item_command.rb
# encoding: UTF-8

class TransferItemCommand
  def initialize(sender, target, item_name, sheet_manager)
    @sender        = sender.to_s.gsub('@', '')
    @target        = target.to_s.gsub('@', '')
    @item_name     = item_name.to_s.strip
    @sheet_manager = sheet_manager
  end

  def execute
    sender = @sheet_manager.find_user(@sender)
    return "@#{@sender} 등록되지 않은 계정입니다." unless sender

    target = @sheet_manager.find_user(@target)
    return "@#{@sender} @#{@target} 계정을 찾을 수 없습니다." unless target

    sender_items = sender[:items].split(',').map(&:strip).reject(&:empty?)
    idx = sender_items.index(@item_name)
    return "@#{@sender} 소지하고 있지 않은 아이템입니다: #{@item_name}" unless idx

    sender_items.delete_at(idx)
    target_items = target[:items].split(',').map(&:strip).reject(&:empty?)
    target_items << @item_name

    @sheet_manager.update_user(@sender, { items: sender_items.join(',') })
    @sheet_manager.update_user(@target, { items: target_items.join(',') })

    puts "[양도] @#{@sender} → @#{@target} #{@item_name}"
    "@#{@sender} #{@item_name}을(를) @#{@target}에게 양도했습니다."
  end
end
