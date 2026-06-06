# commands/under_tree_command.rb
# encoding: UTF-8

class UnderTreeCommand
  # 이상한 장식품들 (60% 확률)
  WEIRD_ORNAMENTS = [
    "말린 명태",
    "마른 오징어",
    "문어 다리",
    "낡은 양말",
    "구멍 난 속옷",
    "헤진 칫솔",
    "낡은 빗자루 솔",
    "더러운 걸레",
    "깨진 접시 조각",
    "녹슨 못",
    "찌그러진 캔",
    "곰팡이 핀 빵",
    "오래된 신문지",
    "바스락거리는 비닐봉지",
    "쓰레기통 뚜껑",
    "낡은 장갑",
    "헤진 수건",
    "부러진 연필",
    "쭈글쭈글한 종이컵",
    "떨어진 단추",
    "사용한 티백",
    "빈 유리병",
    "낡은 고무줄",
    "뜯어진 포스트잇",
    "낡은 지우개",
    "구겨진 영수증",
    "부러진 나뭇가지",
    "시든 꽃잎",
    "돌멩이",
    "모래 한 줌"
  ]

  # 그럴듯한 장식품들 (30% 확률)
  DECENT_ORNAMENTS = [
    "빨간 리본",
    "은색 리본",
    "솔방울",
    "작은 나뭇가지",
    "종이 눈송이",
    "색종이 체인",
    "면 솜뭉치",
    "털실 뭉치",
    "작은 방울",
    "병뚜껑",
    "반짝이 가루 묻은 종이",
    "색색의 구슬",
    "작은 리본 묶음",
    "포장지 조각",
    "은박지",
    "색깔 있는 실타래",
    "작은 종",
    "털실로 만든 폼폼",
    "나뭇잎",
    "열매"
  ]

  # 정식 오너먼트 (10% 확률)
  PROPER_ORNAMENTS = [
    "금색 크리스마스 볼",
    "은색 크리스마스 볼",
    "빨간 크리스마스 볼",
    "초록 크리스마스 볼",
    "반짝이는 별 장식",
    "천사 장식",
    "종 장식",
    "눈사람 오너먼트",
    "순록 장식",
    "선물 상자 장식",
    "지팡이 사탕 장식",
    "징글벨",
    "크리스마스 리스 미니어처",
    "고드름 장식",
    "스노우볼 오너먼트"
  ]

  def initialize(student_id, sheet_manager)
    @student_id = student_id.gsub('@', '')
    @sheet_manager = sheet_manager
  end

  def execute
    puts "[UNDER_TREE] START user=#{@student_id}"
    
    player = @sheet_manager.find_user(@student_id)
    unless player
      return "@#{@student_id} 아직 학적부에 등록되지 않았어요."
    end

    current_galleons = player[:galleons].to_i
    current_items = player[:items].to_s.split(",").map(&:strip).reject(&:empty?)

    # 확률에 따라 장식품 선택
    rand_value = rand
    
    if rand_value < 0.10  # 10% - 정식 오너먼트
      ornament = PROPER_ORNAMENTS.sample
      reward = rand(5..8)
    elsif rand_value < 0.40  # 30% - 그럴듯한 장식품
      ornament = DECENT_ORNAMENTS.sample
      reward = rand(2..4)
    else  # 60% - 이상한 장식품
      ornament = WEIRD_ORNAMENTS.sample
      reward = rand(1..3)
    end

    # 인벤토리에 추가
    current_items << ornament
    new_items = current_items.join(",")
    new_galleons = current_galleons + reward

    @sheet_manager.update_user(@student_id, {
      galleons: new_galleons,
      items: new_items
    })

    message = "@#{@student_id} 트리 아래에서 장식품을 찾았어요!\n\n"
    message += "#{ornament}\n\n"
    message += "+#{reward}G\n"
    message += "현재 잔액: #{new_galleons}G\n"
    message += "주머니에 추가되었어요!"
    
    puts "[UNDER_TREE] SUCCESS: #{ornament}"
    return message
  end
end
