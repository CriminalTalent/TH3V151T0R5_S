# commands/transfer_item_command.rb
# encoding: UTF-8

class TransferItemCommand
  def initialize(sender, target, item_name, sheet_manager)
    @sender        = normalize_acct(sender)
    @target        = normalize_acct(target)
    @item_names    = item_name.to_s.split(',').map(&:strip).reject(&:empty?)
    @sheet_manager = sheet_manager
  end

  def execute
    return "@#{@sender} 양도할 아이템을 입력해주세요." if @item_names.empty?

    sender = @sheet_manager.find_user(@sender)
    return "@#{@sender} 등록되지 않은 계정입니다." unless sender

    target = @sheet_manager.find_user(@target)
    return "@#{@sender} @#{@target} 계정을 찾을 수 없습니다." unless target

    sender_items = sender[:items]
      .to_s
      .split(',')
      .map(&:strip)
      .reject(&:empty?)

    # 전부 소지하고 있는지 먼저 확인한다 (하나라도 없으면 아무것도 양도하지 않는다)
    temp_items = sender_items.dup
    @item_names.each do |name|
      idx = temp_items.index(name)
      return "@#{@sender} 소지하고 있지 않은 아이템입니다: #{name}" unless idx
      temp_items.delete_at(idx)
    end

    target_items = target[:items]
      .to_s
      .split(',')
      .map(&:strip)
      .reject(&:empty?)

    @item_names.each do |name|
      idx = sender_items.index(name)
      sender_items.delete_at(idx)
      target_items << name
    end

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
      restored_items = sender[:items]
        .to_s
        .split(',')
        .map(&:strip)
        .reject(&:empty?)

      restored = @sheet_manager.update_user(
        @sender,
        items: restored_items.join(',')
      )

      unless restored
        puts(
          "[양도 심각 오류] 보내는 사람 복구 실패: " \
          "@#{@sender} → @#{@target}, #{@item_names.join(',')}"
        )
      end

      return(
        "@#{@sender} @#{@target} 아이템 양도 중 오류가 발생했습니다. " \
        "잠시 후 다시 시도해 주세요."
      )
    end

    puts "[양도] @#{@sender} → @#{@target} #{@item_names.join(',')}"

    items_text = @item_names.join(', ')

    "@#{@sender} @#{@target} #{items_text}을(를) " \
      "#{target[:name]}에게 양도했습니다."
  end

  private

  def normalize_acct(acct)
    acct.to_s.strip.sub(/\A@/, '')
  end
end
