# commands/material_draw_command.rb
# encoding: UTF-8

class MaterialDrawCommand
  def initialize(sender, sheet_manager)
    @sender        = sender.to_s.gsub('@', '')
    @sheet_manager = sheet_manager
  end

  def execute
    user = @sheet_manager.find_user(@sender)
    return "@#{@sender} 등록되지 않은 계정입니다." unless user

    all_mats = load_all_materials
    return "@#{@sender} 레시피 재료를 찾을 수 없습니다." if all_mats.empty?

    drawn = all_mats.sample
    items = user[:items].split(',').map(&:strip).reject(&:empty?)
    items << drawn
    @sheet_manager.update_user(@sender, { items: items.join(',') })

    "@#{@sender} 재료 뽑기 결과: #{drawn}"
  end

  private

  def load_all_materials
    rows = @sheet_manager.read('레시피', 'A:C')
    mats = []
    rows[1..].each do |row|
      next if row.nil?
      [row[0], row[1], row[2]].each do |m|
        mats << m.to_s.strip unless m.to_s.strip.empty?
      end
    end
    mats.uniq
  end
end
