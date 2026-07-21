# commands/recipe_command.rb
# encoding: UTF-8

class RecipeCommand
  def initialize(content, student_id, sheet_manager)
    @content = content
    @student_id = student_id.gsub('@', '')
    @sheet_manager = sheet_manager
    match = content.match(/\[조합\/(.+?)\/(.+?)\/(.+?)\]/)
    if match
      @mat1 = match[1].strip
      @mat2 = match[2].strip
      @mat3 = match[3].strip
    end
  end

  def match?(content)
    content.match?(/\[조합\/(.+?)\/(.+?)\/(.+?)\]/)
  end

  def execute
    return "@#{@student_id} 먼저 등록해주세요." unless @sheet_manager.user_exists?(@student_id)
    return "@#{@student_id} 조합 형식이 잘못되었습니다." unless @mat1 && @mat2 && @mat3

    user_items = @sheet_manager.get_items(@student_id)
    materials_needed = [@mat1, @mat2, @mat3].sort

    # 중복 재료까지 고려한 보유 확인 (개수 기준)
    check_items = user_items.dup
    has_all = materials_needed.all? do |m|
      i = check_items.index(m)
      i ? (check_items.delete_at(i); true) : false
    end

    unless has_all
      return "@#{@student_id} 필요한 재료가 부족합니다."
    end

    recipes = @sheet_manager.get_recipes
    recipe = recipes.find do |r|
      recipe_mats = [r[0].to_s.strip, r[1].to_s.strip, r[2].to_s.strip].sort
      recipe_mats == materials_needed
    end

    return "@#{@student_id} 그 조합은 없습니다." unless recipe

    result_item = recipe[3].to_s.strip
    return "@#{@student_id} 조합 결과가 없습니다." if result_item.empty?

    # 재료당 1개씩만 제거
    new_items = user_items.dup
    [@mat1, @mat2, @mat3].each do |m|
      i = new_items.index(m)
      new_items.delete_at(i) if i
    end

    new_items << result_item
    @sheet_manager.set_items(@student_id, new_items)

    "@#{@student_id} 재료를 사용하여 '#{result_item}'을(를) 획득했습니다."
  end
end
