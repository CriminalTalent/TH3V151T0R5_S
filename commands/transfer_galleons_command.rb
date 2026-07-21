# ============================================
# commands/transfer_galleons_command.rb
# ============================================

class TransferGalleonsCommand
  def initialize(sender, receiver, amount, sheet_manager)
    @sender        = normalize_acct(sender)
    @receiver      = normalize_acct(receiver)
    @amount        = amount.to_i
    @sheet_manager = sheet_manager
  end

  def execute
    puts(
      "[TRANSFER_GALLEONS] START " \
      "from=#{@sender} to=#{@receiver} amount=#{@amount}"
    )

    # -----------------------------------------
    # 1) 보내는 사람 확인
    # -----------------------------------------
    sender_user = @sheet_manager.find_user(@sender)

    unless sender_user
      puts(
        "[TRANSFER_GALLEONS] ERROR: " \
        "sender not found (@#{@sender})"
      )

      return "@#{@sender} 아직 학적부에 등록되지 않았어요."
    end

    # -----------------------------------------
    # 2) 받는 사람 확인
    # -----------------------------------------
    receiver_user = @sheet_manager.find_user(@receiver)

    unless receiver_user
      puts(
        "[TRANSFER_GALLEONS] ERROR: " \
        "receiver not found (@#{@receiver})"
      )

      return(
        "@#{@sender} @#{@receiver}님을 " \
        "학적부에서 찾을 수 없어요."
      )
    end

    # -----------------------------------------
    # 3) 자기 자신에게 양도 방지
    # -----------------------------------------
    if @sender.casecmp?(@receiver)
      puts "[TRANSFER_GALLEONS] ERROR: self transfer"

      return "@#{@sender} 자기 자신에게는 갈레온을 양도할 수 없어요."
    end

    # -----------------------------------------
    # 4) 금액 유효성 검사
    # -----------------------------------------
    if @amount <= 0
      puts(
        "[TRANSFER_GALLEONS] ERROR: " \
        "invalid amount (#{@amount})"
      )

      return "@#{@sender} 양도할 갈레온은 0보다 커야 해요."
    end

    # -----------------------------------------
    # 5) 보내는 사람 잔액 및 부채 확인
    # -----------------------------------------
    sender_galleons = sender_user[:credits].to_i

    if sender_galleons < 0
      puts "[TRANSFER_GALLEONS] ERROR: sender has debt"

      return(
        "@#{@sender} 빚이 있는 상태에서는 " \
        "갈레온을 양도할 수 없어요."
      )
    end

    if sender_galleons < @amount
      puts(
        "[TRANSFER_GALLEONS] ERROR: insufficient balance " \
        "(has: #{sender_galleons}, needs: #{@amount})"
      )

      return(
        "@#{@sender} 갈레온이 부족해요. " \
        "(보유: #{sender_galleons}G, 필요: #{@amount}G)"
      )
    end

    # -----------------------------------------
    # 6) 양도 후 잔액 계산
    # -----------------------------------------
    receiver_galleons = receiver_user[:credits].to_i

    new_sender_galleons   = sender_galleons - @amount
    new_receiver_galleons = receiver_galleons + @amount

    if new_sender_galleons < 0
      puts(
        "[TRANSFER_GALLEONS] ERROR: " \
        "transfer would cause debt"
      )

      return(
        "@#{@sender} 양도 후 갈레온이 " \
        "마이너스가 될 수 없어요."
      )
    end

    # -----------------------------------------
    # 7) 보내는 사람 차감
    # -----------------------------------------
    sender_updated = @sheet_manager.update_user(
      @sender,
      credits: new_sender_galleons
    )

    unless sender_updated
      puts(
        "[TRANSFER_GALLEONS] ERROR: " \
        "failed to update sender"
      )

      return(
        "@#{@sender} 갈레온 양도 중 오류가 발생했어요. " \
        "잠시 후 다시 시도해 주세요."
      )
    end

    # -----------------------------------------
    # 8) 받는 사람 지급
    # -----------------------------------------
    receiver_updated = @sheet_manager.update_user(
      @receiver,
      credits: new_receiver_galleons
    )

    unless receiver_updated
      puts(
        "[TRANSFER_GALLEONS] ERROR: " \
        "failed to update receiver; attempting rollback"
      )

      rollback_success = @sheet_manager.update_user(
        @sender,
        credits: sender_galleons
      )

      unless rollback_success
        puts(
          "[TRANSFER_GALLEONS] CRITICAL: rollback failed " \
          "sender=#{@sender} receiver=#{@receiver} " \
          "amount=#{@amount}"
        )
      end

      return(
        "@#{@sender} @#{@receiver} 갈레온 양도 중 " \
        "오류가 발생했어요. 잠시 후 다시 시도해 주세요."
      )
    end

    puts(
      "[TRANSFER_GALLEONS] SUCCESS: " \
      "#{@sender}(#{sender_galleons}→#{new_sender_galleons}) → " \
      "#{@receiver}(#{receiver_galleons}→#{new_receiver_galleons})"
    )

    # -----------------------------------------
    # 9) 결과 메시지
    # -----------------------------------------
    "@#{@sender} @#{@receiver} #{@amount}G을(를) 양도했어요!\n" \
      "보낸 사람 잔액: #{new_sender_galleons}G\n" \
      "받은 사람 잔액: #{new_receiver_galleons}G"
  end

  private

  def normalize_acct(acct)
    acct.to_s.gsub('@', '').strip
  end
end
