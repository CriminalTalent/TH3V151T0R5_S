# commands/transfer_credits_command.rb
# encoding: UTF-8

class TransferCreditsCommand
  def initialize(sender, target, amount, sheet_manager)
    @sender        = sender.to_s.gsub('@', '')
    @target        = target.to_s.gsub('@', '')
    @amount        = amount.to_i
    @sheet_manager = sheet_manager
  end

  def execute
    return "@#{@sender} 0 이하는 송금할 수 없습니다." if @amount <= 0

    sender = @sheet_manager.find_user(@sender)
    return "@#{@sender} 등록되지 않은 계정입니다." unless sender

    target = @sheet_manager.find_user(@target)
    return "@#{@sender} @#{@target} 계정을 찾을 수 없습니다." unless target

    if sender[:credits] < @amount
      return "@#{@sender} 크레딧이 부족합니다. 현재: #{sender[:credits]}C"
    end

    @sheet_manager.update_user(@sender, { credits: sender[:credits] - @amount })
    @sheet_manager.update_user(@target, { credits: target[:credits] + @amount })

    puts "[송금] @#{@sender} → @#{@target} #{@amount}C"
    "@#{@sender} → @#{@target} #{@amount}크레딧 송금 완료.\n잔여: #{sender[:credits] - @amount}C"
  end
end
