# commands/donation_command.rb
# encoding: UTF-8
class DonationCommand
  def initialize(sender, amount, sheet_manager)
    @sender = sender.to_s.gsub('@', '').strip
    @amount = amount.to_i
    @sheet_manager = sheet_manager
  end
  def execute
    return "@#{@sender} 기부 금액은 1 이상으로 입력해주세요.\n예: [기부/30]" if @amount <= 0
    user = @sheet_manager.find_user(@sender)
    return "@#{@sender} 아직 등록되지 않은 계정입니다." unless user
    house = user[:house].to_s.strip
    return "@#{@sender} 사용자 기숙사 정보가 없습니다. 사용자 탭의 기숙사를 확인해주세요." if house.empty?
    credits = user[:credits].to_i
    if credits < @amount
      return "@#{@sender} 보유 크레딧이 부족합니다.\n현재 보유 크레딧: #{credits}"
    end
    new_credits = credits - @amount
    unless @sheet_manager.update_user(@sender, { credits: new_credits })
      return "@#{@sender} 크레딧 차감 중 오류가 발생했습니다."
    end
    new_house_score = @sheet_manager.add_house_credits(house, @amount)
    unless new_house_score
      @sheet_manager.update_user(@sender, { credits: credits })
      return "@#{@sender} 기숙사 점수 반영 중 오류가 발생했습니다. 기숙사 탭의 기숙사명을 확인해주세요."
    end
    "@#{@sender} [기부 완료]\n\n#{@amount}크레딧을 기부했습니다.\n\n#{house} 기숙사\n+#{@amount}점\n\n현재 #{house} 점수: #{new_house_score}점\n현재 보유 크레딧: #{new_credits}"
  rescue => e
    puts "[DonationCommand 오류] #{e.class}: #{e.message}"
    "@#{@sender} 기부 처리 중 오류가 발생했습니다."
  end
end
