# commands/material_command.rb
# encoding: UTF-8

class MaterialCommand
  COST = 10

  def initialize(content, student_id, sheet_manager)
    @content = content
    @student_id = student_id.gsub('@', '')
    @sheet_manager = sheet_manager
  end

  def match?(content)
    content.match?(/\[잡동사니\]/)
  end

  def execute
    user = @sheet_manager.find_user(@student_id)
    return "@#{@student_id} 먼저 등록해주세요." unless user

    credits = user[:credits].to_i
    if credits < COST
      return "@#{@student_id} 크레딧이 부족합니다. (필요: #{COST}크레딧, 보유: #{credits}크레딧)"
    end

    recipes = @sheet_manager.get_recipes
    return "@#{@student_id} 레시피 시트를 불러올 수 없습니다." if recipes.empty?

    columns = [0, 1, 2]
    random_col = columns.sample
    random_row = recipes.sample
    material = random_row[random_col]

    return "@#{@student_id} 재료를 뽑지 못했습니다." if material.nil? || material.to_s.strip.empty?

    new_credits = credits - COST
    @sheet_manager.update_user(@student_id, { credits: new_credits })

    items = @sheet_manager.get_items(@student_id)
    items << material
    @sheet_manager.set_items(@student_id, items)

    "@#{@student_id} #{COST}크레딧을 사용하여 재료 '#{material}'을(를) 획득했습니다.\n잔여 크레딧: #{new_credits}크레딧"
  end
end
