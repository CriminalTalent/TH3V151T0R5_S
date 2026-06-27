# commands/material_command.rb
class MaterialCommand
  def initialize(content, student_id, sheet_manager)
    @student_id = student_id.gsub('@', '')
    @sheet_manager = sheet_manager
  end

  def match?(content)
    content.match?(/\[재료뽑기\]/)
  end

  def execute(content:, account:, status_id:)
    return "먼저 등록해주세요." unless @sheet_manager.user_exists?(account)

    recipes = @sheet_manager.get_recipes
    return "레시피 시트를 불러올 수 없습니다." if recipes.empty?

    columns = [0, 1, 2]
    random_col = columns.sample
    random_row = recipes.sample
    material = random_row[random_col]

    return "재료를 뽑지 못했습니다." if material.nil? || material.to_s.strip.empty?

    items = @sheet_manager.get_items(account)
    items << material
    @sheet_manager.set_items(account, items)

    @sheet_manager.log(account, "재료뽑기", material)

    "재료 '#{material}'을(를) 획득했습니다."
  end
end
