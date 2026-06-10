# commands/stat_buy_command.rb
# encoding: UTF-8
# [스탯구매/스탯명] - 스탯 포인트 1포인트 소모해 해당 스탯 1 증가
# 스탯 포인트는 사용자 시트 K열(stat_points)에서 차감

class StatBuyCommand
  STAT_ALIASES = {
    '건강'    => '건강',
    '체력'    => '건강',
    '마법능력' => '마법능력',
    '공격'    => '마법능력',
    '인내'    => '인내',
    '방어'    => '인내',
    '속도'    => '속도',
    '민첩'    => '속도',
    '기술'    => '기술',
    '명중'    => '기술',
    '행운'    => '행운',
    '크리티컬' => '행운'
  }.freeze

  STAT_COL = SheetManager::STAT_NAMES  # sheet_manager.rb의 STAT_NAMES 참조

  def initialize(content, student_id, sheet_manager)
    @student_id    = student_id.to_s.gsub('@', '')
    @sheet_manager = sheet_manager
    match = content.match(/\[스탯구매\/(.+?)\]/)
    @input_stat = match ? match[1].strip : nil
  end

  def execute
    return "@#{@student_id} 형식이 잘못되었습니다. 예: [스탯구매/건강]" unless @input_stat

    stat_name = STAT_ALIASES[@input_stat]
    return "@#{@student_id} #{@input_stat}은(는) 올바른 스탯명이 아닙니다.\n사용 가능: 건강, 마법능력, 인내, 속도, 기술, 행운" unless stat_name

    user  = @sheet_manager.find_user(@student_id)
    return "@#{@student_id} 등록되지 않은 계정입니다." unless user

    if user[:stat_points] < 1
      return "@#{@student_id} 스탯 포인트가 없습니다. 현재 잔여: #{user[:stat_points]}pt"
    end

    stats = @sheet_manager.find_stats(@student_id)
    return "@#{@student_id} 스탯 정보를 찾을 수 없습니다." unless stats

    stat_key_map = {
      '건강'    => :health,
      '마법능력' => :magic,
      '인내'    => :endurance,
      '속도'    => :speed,
      '기술'    => :skill,
      '행운'    => :luck
    }

    stat_key  = stat_key_map[stat_name]
    old_val   = stats[stat_key]
    new_val   = old_val + 1
    new_pts   = user[:stat_points] - 1

    @sheet_manager.update_stat(@student_id, stat_name, new_val)
    @sheet_manager.update_user(@student_id, { stat_points: new_pts })

    puts "[스탯구매] @#{@student_id} #{stat_name} #{old_val} → #{new_val}, 잔여pt: #{new_pts}"
    "@#{@student_id} #{stat_name} 스탯이 #{old_val} → #{new_val}이 되었습니다.\n잔여 스탯 포인트: #{new_pts}pt"
  end
end
