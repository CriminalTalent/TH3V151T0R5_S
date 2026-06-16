# commands/hideout_command.rb
# encoding: UTF-8

class HideoutCommand
  def initialize(sender, sheet_manager)
    @sender        = sender.to_s.gsub('@', '')
    @sheet_manager = sheet_manager
  end

  def execute
    user = @sheet_manager.find_user(@sender)
    return "@#{@sender} 등록되지 않은 계정입니다." unless user

    items = user[:items].split(',').map(&:strip).reject(&:empty?)
    recipes = load_recipes

    available = []
    recipes.each do |recipe|
      mats = recipe[:mats]
      temp = items.dup
      can_make = mats.all? do |mat|
        idx = temp.index(mat)
        if idx
          temp.delete_at(idx)
          true
        else
          false
        end
      end
      available << recipe if can_make
    end

    if available.empty?
      return "@#{@sender} 현재 보유한 재료로 만들 수 있는 조합이 없습니다."
    end

    lines = ["@#{@sender} 만들 수 있는 조합 목록"]
    lines << "──────────────────"
    available.each do |r|
      lines << "#{r[:mats].join(' + ')} → #{r[:result]}"
    end
    lines << "──────────────────"
    lines.join("\n")
  end

  private

  def load_recipes
    rows = @sheet_manager.read('레시피', 'A:D')
    result = []
    rows[1..].each do |row|
      next if row.nil? || row[0].nil?
      mats = [row[0], row[1], row[2]].map(&:to_s).map(&:strip).reject(&:empty?)
      res  = row[3].to_s.strip
      next if mats.size < 3 || res.empty?
      result << { mats: mats, result: res }
    end
    result
  end
end
