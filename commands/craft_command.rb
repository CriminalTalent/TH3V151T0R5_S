# commands/craft_command.rb
# encoding: UTF-8

class CraftCommand
  def initialize(content, sender, sheet_manager)
    @sender        = sender.to_s.gsub('@', '')
    @sheet_manager = sheet_manager
    match = content.match(/\[조합\/(.+?)\/(.+?)\/(.+?)\]/)
    if match
      @mat1 = match[1].strip
      @mat2 = match[2].strip
      @mat3 = match[3].strip
    end
  end

  def execute
    return "@#{@sender} 형식이 잘못되었습니다. 예: [조합/재료1/재료2/재료3]" unless @mat1

    user = @sheet_manager.find_user(@sender)
    return "@#{@sender} 등록되지 않은 계정입니다." unless user

    recipe = find_recipe(@mat1, @mat2, @mat3)
    return "@#{@sender} 해당 재료 조합의 레시피를 찾을 수 없습니다." unless recipe

    items = user[:items].split(',').map(&:strip).reject(&:empty?)

    [@mat1, @mat2, @mat3].each do |mat|
      idx = items.index(mat)
      return "@#{@sender} 재료 '#{mat}'을(를) 소지하고 있지 않습니다." unless idx
      items.delete_at(idx)
    end

    items << recipe
    @sheet_manager.update_user(@sender, { items: items.join(',') })

    "@#{@sender} 조합 성공!\n#{@mat1} + #{@mat2} + #{@mat3} → #{recipe}"
  end

  private

  def find_recipe(mat1, mat2, mat3)
    input = [mat1, mat2, mat3].map(&:strip).sort
    rows = @sheet_manager.read('레시피', 'A:D')
    rows[1..].each do |row|
      next if row.nil? || row[0].nil?
      recipe_mats = [row[0], row[1], row[2]].map(&:to_s).map(&:strip).sort
      return row[3].to_s.strip if recipe_mats == input
    end
    nil
  end
end
