# commands/recipe_command.rb
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

  def execute(content:, account:, status_id:)
    return "먼저 등록해주세요." unless @sheet_manager.user_exists?(account)
    return "조합 형식이 잘못되었습니다." unless @mat1 && @mat2 && @mat3

    user_items = @sheet_manager.get_items(account)
    materials_needed = [@mat1, @mat2, @mat3].sort
    user_sorted = user_items.sort

    unless materials_needed.all? { |m| user_sorted.include?(m) }
      return "필요한 재료가 부족합니다."
    end

    recipes = @sheet_manager.get_recipes
    recipe = recipes.find do |r|
      recipe_mats = [r[0].to_s.strip, r[1].to_s.strip, r[2].to_s.strip].sort
      recipe_mats == materials_needed
    end

    return "그 조합은 없습니다." unless recipe

    result_item = recipe[3].to_s.strip
    return "조합 결과가 없습니다." if result_item.empty?

    new_items = user_items.reject { |i| [@mat1, @mat2, @mat3].include?(i) }
    new_items << result_item
    @sheet_manager.set_items(account, new_items)

    @sheet_manager.log(account, "조합", "#{@mat1}/#{@mat2}/#{@mat3} → #{result_item}")

    "재료를 사용하여 '#{result_item}'을(를) 획득했습니다."
  end
end
