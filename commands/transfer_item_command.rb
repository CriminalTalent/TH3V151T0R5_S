# commands/transfer_item_command.rb
# encoding: UTF-8

class TransferItemCommand
  def initialize(sender, target, item_name, sheet_manager)
    @sender        = normalize_acct(sender)
    @target        = normalize_acct(target)
    @item_name     = item_name.to_s.strip
    @sheet_manager = sheet_manager
  end

  def execute
    sender = @sheet_manager.find_user(@sender)
    return "@#{@sender} 등록되지 않은 계정입니다." unless sender

    target = @sheet_manager.find_user(@target)
    return "@#{@sender} @#{@target} 계정을 찾을 수 없습니다." unless target

    sender_items = sender[:items]
      .to_s
      .split(',')
      .map(&:strip)
      .reject(&:empty?)

    item_index = sender_items.index(@item_name)

    unless item_index
      return "@#{@sender} 소지하고 있지 않은 아이템입니다: #{@item_name}"
    end

    target_items = target[:items]
      .to_s
      .split(',')
      .map(&:strip)
      .reject(&:empty?)

    sender_items.delete_at(item_index)
    target_items << @item_name

    sender_updated = @sheet_manager.update_user(
      @sender,
      items: sender_items.join(',')
    )

    unless sender_updated
      return "@#{@sender} 아이템 양도 중 오류가 발생했습니다. 잠시 후 다시 시도해 주세요."
    end

    target_updated = @sheet_manager.update_user(
      @target,
      items: target_items.join(',')
    )

    unless target_updated
      # 상대방 지급이 실패했을 경우 보내는 사람의 아이템을 복구한다.
      sender_items << @item_name

      restored = @sheet_manager.update_user(
        @sender,
        items: sender_items.join(',')
      )

      unless restored
        puts(
          "[양도 심각 오류] 보내는 사람 복구 실패: " \
          "@#{@sender} → @#{@target}, #{@item_name}"
        )
      end

      return(
        "@#{@sender} @#{@target} 아이템 양도 중 오류가 발생했습니다. " \
        "잠시 후 다시 시도해 주세요."
      )
    end

    puts "[양도] @#{@sender} → @#{@target} #{@item_name}"

    "@#{@sender} @#{@target} #{@item_name}을(를) " \
      "#{target[:name]}에게 양도했습니다."
  end

  private

  def normalize_acct(acct)
    acct.to_s.strip.sub(/\A@/, '')
  end
end
