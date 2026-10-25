# commands/junk_command.rb
# encoding: UTF-8
# [잡동사니]    - 10크레딧 소모, 레시피 시트에서 재료 1개 랜덤 획득
# [잡동사니/N]  - 한 번에 N개 구매 (최대 MAX_COUNT개), 개당 10크레딧

class JunkCommand
  COST = 10
  MAX_COUNT = 10

  def initialize(content, student_id, sheet_manager)
    @content = content
    @student_id = student_id.gsub('@', '')
    @sheet_manager = sheet_manager
  end

  def execute
    count = requested_count
    return "@#{@student_id} 구매 개수는 1 이상이어야 합니다." if count < 1
    if count > MAX_COUNT
      return "@#{@student_id} 잡동사니는 한 번에 최대 #{MAX_COUNT}개까지 구매할 수 있습니다."
    end

    user = @sheet_manager.find_user(@student_id)
    return "@#{@student_id} 먼저 등록해주세요." unless user

    credits = user[:credits].to_i
    need = COST * count
    if credits < need
      affordable = [credits / COST, 0].max
      if count == 1
        return "@#{@student_id} 크레딧이 부족합니다. 현재 #{credits}크레딧, 필요 #{COST}크레딧."
      end
      msg = "@#{@student_id} 크레딧이 부족합니다. #{count}개를 구매하려면 #{need}크레딧이 필요합니다. 현재 #{credits}크레딧."
      msg += " (최대 #{[affordable, MAX_COUNT].min}개 구매 가능)" if affordable > 0
      return msg
    end

    recipes = @sheet_manager.get_recipes
    return "@#{@student_id} 레시피 시트를 불러올 수 없습니다." if recipes.empty?

    materials = Array.new(count) { draw_material(recipes) }.compact
    return "@#{@student_id} 재료를 뽑지 못했습니다." if materials.empty?

    cost = COST * materials.size
    new_credits = credits - cost

    saved = @sheet_manager.update_user(@student_id, { credits: new_credits })
    unless saved
      return "@#{@student_id} 크레딧 저장 중 오류가 발생했습니다. 재료는 지급되지 않았습니다. [소지품]으로 확인 후 다시 시도해주세요."
    end

    items = user[:items].to_s.split(',').map(&:strip).reject(&:empty?)
    items.concat(materials)
    items_saved = @sheet_manager.set_items(@student_id, items)
    unless items_saved
      @sheet_manager.update_user(@student_id, { credits: credits })
      return "@#{@student_id} 재료 저장 중 오류가 발생했습니다. 크레딧은 되돌렸습니다. [소지품]으로 확인 후 다시 시도해주세요."
    end

    build_result(materials, count, cost, new_credits)
  end

  private

  def requested_count
    m = @content.to_s.match(/\[잡동사니\/(\d+)\]/)
    m ? m[1].to_i : 1
  end

  def draw_material(recipes)
    20.times do
      row = recipes.sample
      material = row && row[[0, 1, 2].sample]
      return material unless material.nil? || material.to_s.strip.empty?
    end
    nil
  end

  def build_result(materials, count, cost, new_credits)
    if materials.size == 1
      return "@#{@student_id} #{cost}크레딧을 사용해 재료 '#{materials.first}'을(를) 획득했습니다.\n잔여 크레딧: #{new_credits}크레딧"
    end

    lines = ["@#{@student_id} #{cost}크레딧을 사용해 재료 #{materials.size}개를 획득했습니다."]
    materials.tally.each { |name, n| lines << "· #{name} ×#{n}" }
    lines << "(요청 #{count}개 중 #{materials.size}개만 뽑혀 그만큼만 차감했습니다.)" if materials.size < count
    lines << "잔여 크레딧: #{new_credits}크레딧"
    lines.join("\n")
  end
end
