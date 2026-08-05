class AnimalFarmCommand
  ANIMALS = ['🦊', '🐱', '🐯', '🐷', '🐼', '🐰', '🐬'].freeze
  LUCKY = '✌'.freeze
  SYMBOLS = (ANIMALS + [LUCKY]).freeze
  DAILY_LIMIT = 3
  MULTIPLIERS = {
    lucky_jackpot: 7.0,
    four_match: 5.0,
    three_match: 4.0,
    two_pair: 2.0,
    one_pair: 1.2,
    none: 0.0
  }.freeze

  def initialize(content, student_id, sheet_manager)
    @content = content
    @student_id = student_id
    @sheet_manager = sheet_manager
  end

  def execute
    match = @content.match(/\[동물농장\/(\d+)\]/)
    return nil unless match

    amount = match[1].to_i

    if amount <= 0
      return "@#{@student_id} 베팅 금액이 올바르지 않습니다."
    end

    user = @sheet_manager.find_user(@student_id)
    unless user
      return "@#{@student_id} 사용자를 찾을 수 없습니다."
    end

    current_credits = user[:credits].to_i
    if current_credits < amount
      return "@#{@student_id} 크레딧이 부족합니다. (현재: #{current_credits})"
    end

    today = Time.now.strftime('%Y-%m-%d')

    begin
      all_users = @sheet_manager.read('사용자', 'A:S')
      current_row = all_users[user[:row_num] - 1] || []
      last_farm_date = current_row[17].to_s.strip
      today_farm_count = (current_row[18] || 0).to_i
    rescue => e
      puts "[FARM] 시트 읽기 실패: #{e.message}"
      return "@#{@student_id} 동물농장 처리 중 오류가 발생했습니다."
    end

    if last_farm_date == today && today_farm_count >= DAILY_LIMIT
      return "@#{@student_id} 오늘 동물농장 기회는 모두 사용했습니다. (#{today_farm_count}/#{DAILY_LIMIT})"
    end

    if last_farm_date != today
      today_farm_count = 0
    end

    slots = spin_slots
    result_type, multiplier = judge_result(slots)

    payout = (amount * multiplier).to_i
    credit_change = payout - amount
    new_credits = current_credits + credit_change

    @sheet_manager.update_user(@student_id, { credits: new_credits })

    begin
      range = "R#{user[:row_num]}:S#{user[:row_num]}"
      @sheet_manager.write('사용자', range, [[today, today_farm_count + 1]])
    rescue => e
      puts "[FARM] 시트 쓰기 실패: #{e.message}"
    end

    format_result(slots, result_type, amount, payout, credit_change, new_credits, today_farm_count + 1)
  end

  private

  def spin_slots
    [SYMBOLS.sample, SYMBOLS.sample, SYMBOLS.sample, SYMBOLS.sample]
  end

  def judge_result(slots)
    return [:lucky_jackpot, MULTIPLIERS[:lucky_jackpot]] if slots.all? { |s| s == LUCKY }

    counts = slots.tally.values.sort.reverse

    if counts[0] == 4
      [:four_match, MULTIPLIERS[:four_match]]
    elsif counts[0] == 3
      [:three_match, MULTIPLIERS[:three_match]]
    elsif counts[0] == 2 && counts[1] == 2
      [:two_pair, MULTIPLIERS[:two_pair]]
    elsif counts[0] == 2
      [:one_pair, MULTIPLIERS[:one_pair]]
    else
      [:none, MULTIPLIERS[:none]]
    end
  end

  def format_result(slots, result_type, bet, payout, change, new_credits, count)
    symbols = slots.join(' - ')

    result_text = case result_type
                  when :lucky_jackpot
                    "✌✌✌✌ 잭팟!"
                  when :four_match
                    "4개 매치!"
                  when :three_match
                    "3개 매치!"
                  when :two_pair
                    "투페어!"
                  when :one_pair
                    "원페어"
                  else
                    "꽝..."
                  end

    sign = change >= 0 ? '+' : ''
    "@#{@student_id} [ #{symbols} ] #{result_text}\n베팅: #{bet} → 지급: #{payout} (#{sign}#{change}크레딧)\n잔여 크레딧: #{new_credits}C\n남은 기회: #{DAILY_LIMIT - count}/#{DAILY_LIMIT}"
  end
end
