# commands/bet_command.rb
# encoding: UTF-8
# 행운 스탯이 높을수록 유리한 배율 가중치 적용
# 배율 범위: -5 ~ +5 (0 포함), 음수 가능

class BetCommand
  MAX_BETS_PER_DAY = 3

  def initialize(sender, amount, sheet_manager)
    @sender        = sender.to_s.gsub('@', '')
    @amount        = amount.to_i
    @sheet_manager = sheet_manager
  end

  def execute
    return "@#{@sender} 베팅 금액은 1 이상이어야 합니다." if @amount <= 0

    user  = @sheet_manager.find_user(@sender)
    return "@#{@sender} 등록되지 않은 계정입니다." unless user

    if user[:credits] < 0
      return "@#{@sender} 크레딧이 음수 상태에서는 베팅할 수 없습니다."
    end

    if user[:credits] < @amount
      return "@#{@sender} 크레딧이 부족합니다. 현재: #{user[:credits]}C"
    end

    today = Time.now.strftime('%Y-%m-%d')
    bet_count = user[:last_bet_date] == today ? user[:today_bet_count].to_i : 0

    if bet_count >= MAX_BETS_PER_DAY
      return "@#{@sender} 오늘 베팅 횟수를 모두 사용했습니다. (#{MAX_BETS_PER_DAY}회/일)"
    end

    # 행운 스탯 기반 가중치
    # 행운이 높을수록 양수 배율에 더 많은 가중치
    luck = (user_stats_luck(@sender) || 5).clamp(0, 30)
    multiplier = weighted_multiplier(luck)

    profit    = @amount * multiplier
    new_credits = user[:credits] + profit

    @sheet_manager.update_user(@sender, {
      credits:         new_credits,
      last_bet_date:   today,
      today_bet_count: bet_count + 1
    })

    sign = profit >= 0 ? '+' : ''
    "@#{@sender} #{@amount}C 베팅 결과\n" \
    "배율: #{multiplier > 0 ? '+' : ''}#{multiplier}배 / 손익: #{sign}#{profit}C\n" \
    "잔여 크레딧: #{new_credits}C  (오늘 #{bet_count + 1}/#{MAX_BETS_PER_DAY}회)"
  end

  private

  def user_stats_luck(acct)
    stats = @sheet_manager.find_stats(acct)
    stats ? stats[:luck] : 5
  end

  # 행운 0~30 → 배율 -5~+5 가중 샘플
  # 행운이 낮을수록 음수 가중, 높을수록 양수 가중
  def weighted_multiplier(luck)
    pool = []
    (-5..5).each do |m|
      # 기본 가중치 1, 양수일수록 luck에 비례해 추가
      weight = if m >= 0
                 1 + (luck * m / 10.0).to_i
               else
                 1 + ((30 - luck) * m.abs / 10.0).to_i
               end
      weight = [weight, 1].max
      weight.times { pool << m }
    end
    pool.sample
  end
end
