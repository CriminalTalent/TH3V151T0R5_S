# ============================================
# commands/transfer_galleons_command.rb
# ============================================
class TransferGalleonsCommand
  def initialize(sender, receiver, amount, sheet_manager)
    @sender = sender.gsub('@', '')
    @receiver = receiver.gsub('@', '')
    @amount = amount.to_i
    @sheet_manager = sheet_manager
  end

  def execute
    puts "[TRANSFER_GALLEONS] START from=#{@sender} to=#{@receiver} amount=#{@amount}"

    # -----------------------------------------
    # 1) 보내는 사람 확인
    # -----------------------------------------
    sender_user = @sheet_manager.find_user(@sender)
    unless sender_user
      puts "[TRANSFER_GALLEONS] ERROR: sender not found (@#{@sender})"
      return "@#{@sender} 아직 학적부에 등록되지 않았어요."
    end

    # -----------------------------------------
    # 2) 받는 사람 확인
    # -----------------------------------------
    receiver_user = @sheet_manager.find_user(@receiver)
    unless receiver_user
      puts "[TRANSFER_GALLEONS] ERROR: receiver not found (@#{@receiver})"
      return "@#{@sender} @#{@receiver}님을 학적부에서 찾을 수 없어요."
    end

    # -----------------------------------------
    # 3) 금액 유효성 검사
    # -----------------------------------------
    if @amount <= 0
      puts "[TRANSFER_GALLEONS] ERROR: invalid amount (#{@amount})"
      return "@#{@sender} 양도할 갈레온은 0보다 커야 해요."
    end

    # -----------------------------------------
    # 4) 보내는 사람 잔액 확인
    # -----------------------------------------
    sender_galleons = sender_user[:galleons].to_i
    
    if sender_galleons < @amount
      puts "[TRANSFER_GALLEONS] ERROR: insufficient balance (has: #{sender_galleons}, needs: #{@amount})"
      return "@#{@sender} 갈레온이 부족해요. (보유: #{sender_galleons}G, 필요: #{@amount}G)"
    end

    # -----------------------------------------
    # 5) 부채 체크 (보내는 사람)
    # -----------------------------------------
    if sender_galleons < 0
      puts "[TRANSFER_GALLEONS] ERROR: sender has debt"
      return "@#{@sender} 빚이 있는 상태에서는 갈레온을 양도할 수 없어요."
    end

    # -----------------------------------------
    # 6) 양도 후 부채 체크
    # -----------------------------------------
    new_sender_galleons = sender_galleons - @amount
    if new_sender_galleons < 0
      puts "[TRANSFER_GALLEONS] ERROR: transfer would cause debt"
      return "@#{@sender} 양도 후 갈레온이 마이너스가 될 수 없어요."
    end

    # -----------------------------------------
    # 7) 양도 처리
    # -----------------------------------------
    receiver_galleons = receiver_user[:galleons].to_i
    new_receiver_galleons = receiver_galleons + @amount

    @sheet_manager.update_user(@sender, { galleons: new_sender_galleons })
    @sheet_manager.update_user(@receiver, { galleons: new_receiver_galleons })

    puts "[TRANSFER_GALLEONS] SUCCESS: #{@sender}(#{sender_galleons}→#{new_sender_galleons}) → #{@receiver}(#{receiver_galleons}→#{new_receiver_galleons})"

    # -----------------------------------------
    # 8) 결과 메시지
    # -----------------------------------------
    "@#{@sender} #{@amount}G을(를) @#{@receiver}님에게 양도했어요!\n" \
    "보낸 사람 잔액: #{new_sender_galleons}G\n" \
    "받은 사람 잔액: #{new_receiver_galleons}G"
  end
end
