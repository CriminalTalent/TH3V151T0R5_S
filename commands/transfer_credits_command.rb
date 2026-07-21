# commands/transfer_credits_command.rb
# encoding: UTF-8

class TransferCreditsCommand
  def initialize(sender, receiver, amount, sheet_manager)
    @sender        = normalize_acct(sender)
    @receiver      = normalize_acct(receiver)
    @amount        = amount.to_i
    @sheet_manager = sheet_manager
  end

  def execute
    puts "[송금] START from=#{@sender} to=#{@receiver} amount=#{@amount}"

    sender_user = @sheet_manager.find_user(@sender)
    return "@#{@sender} 등록되지 않은 계정입니다." unless sender_user

    receiver_user = @sheet_manager.find_user(@receiver)
    return "@#{@sender} @#{@receiver} 계정을 찾을 수 없습니다." unless receiver_user

    if @sender.casecmp?(@receiver)
      return "@#{@sender} 자기 자신에게는 송금할 수 없습니다."
    end

    return "@#{@sender} 송금할 금액은 1 이상이어야 합니다." if @amount <= 0

    sender_credits = sender_user[:credits].to_i

    if sender_credits < 0
      return "@#{@sender} 크레딧이 음수 상태에서는 송금할 수 없습니다."
    end

    if sender_credits < @amount
      return "@#{@sender} 크레딧이 부족합니다. (보유: #{sender_credits}C, 필요: #{@amount}C)"
    end

    receiver_credits     = receiver_user[:credits].to_i
    new_sender_credits   = sender_credits - @amount
    new_receiver_credits = receiver_credits + @amount

    sender_updated = @sheet_manager.update_user(@sender, credits: new_sender_credits)
    unless sender_updated
      return "@#{@sender} 송금 중 오류가 발생했습니다. 잠시 후 다시 시도해 주세요."
    end

    receiver_updated = @sheet_manager.update_user(@receiver, credits: new_receiver_credits)
    unless receiver_updated
      rollback_success = @sheet_manager.update_user(@sender, credits: sender_credits)
      unless rollback_success
        puts "[송금 심각 오류] 보내는 사람 복구 실패: @#{@sender} → @#{@receiver}, #{@amount}C"
      end
      return "@#{@sender} 송금 중 오류가 발생했습니다. 잠시 후 다시 시도해 주세요."
    end

    puts "[송금] @#{@sender} → @#{@receiver} #{@amount}C"

    "@#{@sender} #{@amount}C을(를) #{receiver_user[:name]}(@#{@receiver})에게 송금했습니다.\n" \
      "잔여 크레딧: #{new_sender_credits}C"
  end

  private

  def normalize_acct(acct)
    acct.to_s.gsub('@', '').strip
  end
end
