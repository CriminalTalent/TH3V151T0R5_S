# commands/homestead_command.rb
# encoding: UTF-8

class HomesteadCommand
  def initialize(content, student_id, sheet_manager)
    @content = content
    @student_id = student_id.gsub('@', '')
    @sheet_manager = sheet_manager
  end

  def match?(content)
    content.match?(/\[은신처꾸미기\]/)
  end

  def execute
    return "먼저 등록해주세요." unless @sheet_manager.user_exists?(@student_id)

    user_items = @sheet_manager.get_items(@student_id)
    return "보유한 아이템이 없습니다." if user_items.empty?

    recipes = @sheet_manager.get_recipes
    return "레시피 시트를 불러올 수 없습니다." if recipes.empty?

    possible_combinations = recipes.select do |recipe|
      mat1, mat2, mat3, result = recipe[0].to_s.strip, recipe[1].to_s.strip, recipe[2].to_s.strip, recipe[3].to_s.strip
      next if mat1.empty? || mat2.empty? || mat3.empty? || result.empty?

      materials = [mat1, mat2, mat3].sort
      user_sorted = user_items.sort
      materials.all? { |m| user_sorted.include?(m) }
    end

    if possible_combinations.empty?
      return "현재 조합할 수 있는 재료가 없습니다."
    end

    output = "조합 가능한 목록:\n"
    possible_combinations.each do |combo|
      mat1, mat2, mat3, result = combo[0].to_s.strip, combo[1].to_s.strip, combo[2].to_s.strip, combo[3].to_s.strip
      output += "\n[조합/#{mat1}/#{mat2}/#{mat3}] → #{result}"
    end

    output
  end
end
