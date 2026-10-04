# commands/available_recipe_command.rb
# encoding: UTF-8
# [조합가능] - 소지품 재료로 지금 만들 수 있는 조합 목록을 보여준다.

class AvailableRecipeCommand
  def eul_reul(word)
    return "를" if word.nil? || word.to_s.strip.empty?
    last_char = word.to_s.strip[-1]
    code = last_char.ord
    return "를" unless code.between?(0xAC00, 0xD7A3)
    has_batchim = ((code - 0xAC00) % 28) != 0
    has_batchim ? "을" : "를"
  end

  def initialize(content, student_id, sheet_manager)
    @content = content
    @student_id = student_id.gsub('@', '')
    @sheet_manager = sheet_manager
  end

  def match?(content)
    content.match?(/\[조합가능\]/)
  end

  def execute
    return "@#{@student_id} 먼저 등록해주세요." unless @sheet_manager.user_exists?(@student_id)

    items = @sheet_manager.get_items(@student_id)
    return "@#{@student_id} 소지품이 비어 있습니다." if items.empty?

    recipes = @sheet_manager.get_recipes
    return "@#{@student_id} 레시피 시트를 불러올 수 없습니다." if recipes.empty?

    # 보유 개수 집계 (같은 재료 여러 개 보유 고려)
    counts = Hash.new(0)
    items.each { |i| counts[i] += 1 }

    craftable = []
    recipes.each do |row|
      mat1 = row[0].to_s.strip
      mat2 = row[1].to_s.strip
      mat3 = row[2].to_s.strip
      result = row[3].to_s.strip
      next if mat1.empty? || mat2.empty? || mat3.empty? || result.empty?

      needed = Hash.new(0)
      [mat1, mat2, mat3].each { |m| needed[m] += 1 }

      has_all = needed.all? { |mat, qty| counts[mat] >= qty }
      craftable << { materials: [mat1, mat2, mat3], result: result } if has_all
    end

    if craftable.empty?
      return "@#{@student_id} 지금 완성할 수 있는 잡동사니가 없습니다."
    end

    lines = craftable.map do |c|
      particle = eul_reul(c[:materials].last)
      "#{c[:materials].join(', ')}#{particle} 사용하여 조합이 가능합니다."
    end

    "@#{@student_id}\n\n#{lines.join("\n")}"
  end
end
