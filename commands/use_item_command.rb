# ============================================
# commands/use_item_command.rb (설명 출력 수정)
# ============================================
# encoding: UTF-8

class UseItemCommand
  def initialize(student_id, item_name, sheet_manager)
    @student_id = student_id.gsub('@', '')
    @item_name = item_name.strip
    @sheet_manager = sheet_manager
  end

  def execute
    puts "[USE] START user=#{@student_id}, item=#{@item_name}"
    
    # -----------------------------------------
    # 1) 플레이어 정보 확인
    # -----------------------------------------
    player = @sheet_manager.find_user(@student_id)
    unless player
      return "@#{@student_id} 아직 학생 등록이 안 되어 있어요~ 교수님께 가서 입학 먼저 하고 오세요!"
    end

    inventory = player[:items].to_s.split(",").map(&:strip)
    puts "[USE] 현재 인벤토리: #{inventory.inspect}"

    unless inventory.include?(@item_name)
      return "@#{@student_id} #{@item_name}… 그건 지금 주머니 안에 없어요."
    end

    # -----------------------------------------
    # 2) 아이템 정보 확인
    # -----------------------------------------
    item = @sheet_manager.find_item(@item_name)
    unless item
      return "@#{@student_id} #{@item_name}? 그런 물건 정보는 찾을 수 없어요."
    end

    puts "[USE] 아이템 정보: #{item.inspect}"

    # 시트 E열: 사용 및 양도 가능 (:usable 키 사용)
    raw_flag = item[:usable]

    # true(boolean) 이거나, "TRUE" 문자열이면 사용 가능으로 처리
    can_use = (raw_flag == true || raw_flag.to_s.strip.upcase == "TRUE")

    puts "[USE] 사용가능 여부: #{raw_flag.inspect} → #{can_use}"

    unless can_use
      return "@#{@student_id} #{@item_name}은(는) 사용하는 물건이 아니에요~"
    end

    # -----------------------------------------
    # 3) 인벤토리에서 제거
    # -----------------------------------------
    inventory.delete_at(inventory.index(@item_name))
    new_items = inventory.join(",")
    
    @sheet_manager.update_user(@student_id, {
      items: new_items
    })

    puts "[USE] 인벤토리 업데이트: #{new_items}"

    # -----------------------------------------
    # 4) 설명 랜덤 출력 기능
    # -----------------------------------------
    raw_desc = item[:description].to_s
    
    puts "[USE] 원본 설명: #{raw_desc}"
      
    desc =
      if raw_desc.include?("/")
        # "A/B/C" → ["A", "B", "C"] → 하나 랜덤
        choices = raw_desc.split("/").map(&:strip).reject(&:empty?)
        selected = choices.sample
        puts "[USE] 랜덤 선택: #{selected}"
        selected
      else
        raw_desc.strip
      end
    
    desc = nil if desc.to_s.strip.empty?

    # -----------------------------------------
    # 5) 결과 출력 (RP 톤 + 멘션 + 설명)
    # -----------------------------------------
    if desc && !desc.empty?
      message = "@#{@student_id} #{@item_name}을(를) 사용했어요.\n\n#{desc}"
    else
      message = "@#{@student_id} #{@item_name}을(를) 사용했어요!"
    end

    puts "[USE] 최종 메시지: #{message[0..100]}..."
    return message
  end
end
