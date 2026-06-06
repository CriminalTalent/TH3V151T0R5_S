# ============================================
# commands/bet_command.rb (출력 형식 수정)
# ============================================
class BetCommand
  MAX_BETS_PER_DAY = 3

  def initialize(student_id, amount, sheet_manager)
    @student_id = student_id.gsub('@', '')
    @amount = amount
    @sheet_manager = sheet_manager
  end

  def execute
    puts "[BET] START user=#{@student_id}, amount=#{@amount}"

    # 플레이어 확인
    player = @sheet_manager.find_user(@student_id)
    unless player
      puts "[BET] ERROR: player not found (@#{@student_id})"
      return "@#{@student_id} 아직 학적부에 등록되지 않았어요."
    end

    current_galleons = player[:galleons].to_i
    puts "[BET] 현재 갈레온: #{current_galleons}"

    # 부채 확인
    if current_galleons < 0
      puts "[BET] BLOCK: 부채 상태"
      return "@#{@student_id} 빚쟁이는 베팅 못 해요!"
    end

    # 잔액 확인
    if current_galleons < @amount
      puts "[BET] BLOCK: 잔액 부족"
      return "@#{@student_id} 갈레온이 부족해요."
    end

    # 베팅 횟수 확인
    today = Time.now.strftime('%Y-%m-%d')
    last_bet_date = player[:last_bet_date].to_s.strip
    
    puts "[BET] 오늘: #{today}, 마지막 베팅 날짜: #{last_bet_date}"

    if last_bet_date == today
      bet_count = player[:bet_count].to_i
    else
      bet_count = 0
    end

    puts "[BET] 오늘 베팅 횟수: #{bet_count}/#{MAX_BETS_PER_DAY}"

    if bet_count >= MAX_BETS_PER_DAY
      puts "[BET] BLOCK: 오늘 베팅 횟수 초과"
      return "@#{@student_id} 오늘은 이미 #{MAX_BETS_PER_DAY}번 베팅했어요."
    end

    # 배당률 랜덤 (-5x ~ +5x)
    multiplier = rand(-5..5)
    profit_loss = @amount * multiplier  # 손익
    new_galleons = current_galleons + profit_loss
    new_bet_count = bet_count + 1

    puts "[BET] 배수: #{multiplier}, 손익: #{profit_loss}, 새 갈레온: #{new_galleons}, 새 카운트: #{new_bet_count}"

    # 업데이트
    @sheet_manager.update_user(@student_id, {
      galleons: new_galleons,
      last_bet_date: today,
      bet_count: new_bet_count
    })

    # 결과 메시지
    message = "@#{@student_id} #{@amount}G 베팅 결과!\n"
    message += "배수: #{multiplier > 0 ? '+' : ''}#{multiplier}, 손익: #{profit_loss > 0 ? '+' : ''}#{profit_loss} G\n"
    message += "현재 잔액: #{new_galleons} G\n"
    message += "(오늘 사용: #{new_bet_count}/#{MAX_BETS_PER_DAY})"

    puts "[BET] SUCCESS: #{message}"
    return message
  end
end
