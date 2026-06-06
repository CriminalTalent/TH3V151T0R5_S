# ============================================
# commands/sell_command.rb
# 주머니 아이템 판매 (무조건 1갈레온)
# ============================================
# encoding: UTF-8

class SellCommand
  SELL_PRICE = 1  # 모든 아이템 판매 가격

  def initialize(student_id, item_name, sheet_manager)
    @student_id = student_id.gsub('@', '')
    @item_name = item_name.strip
    @sheet_manager = sheet_manager
  end

  def execute
    puts "[SELL] START user=#{@student_id}, item=#{@item_name}"

    # -----------------------------------------
    # 1) 플레이어 확인
    # -----------------------------------------
    player = @sheet_manager.find_user(@student_id)
    unless player
      puts "[SELL] ERROR: player not found (@#{@student_id})"
      return "@#{@student_id} 아직 학적부에 등록되지 않았어요."
    end

    current_galleons = player[:galleons].to_i
    inventory = player[:items].to_s.split(",").map(&:strip)

    puts "[SELL] 현재 인벤토리: #{inventory.inspect}"

    # -----------------------------------------
    # 2) 아이템 보유 확인
    # -----------------------------------------
    unless inventory.include?(@item_name)
      puts "[SELL] ERROR: item not in inventory (#{@item_name})"
      return "@#{@student_id} #{@item_name}은(는) 주머니에 없어요."
    end

    # -----------------------------------------
    # 3) 판매 처리
    # -----------------------------------------
    inventory.delete_at(inventory.index(@item_name))
    new_galleons = current_galleons + SELL_PRICE
    new_items = inventory.join(",")

    @sheet_manager.update_user(@student_id, {
      galleons: new_galleons,
      items: new_items
    })

    puts "[SELL] UPDATED: galleons=#{new_galleons}, items=#{new_items}"

    # -----------------------------------------
    # 4) 결과 메시지
    # -----------------------------------------
    "@#{@student_id} #{@item_name}을(를) #{SELL_PRICE}갈레온에 팔았어요.\n" \
    "현재 잔액: #{new_galleons}G"
  end
end
