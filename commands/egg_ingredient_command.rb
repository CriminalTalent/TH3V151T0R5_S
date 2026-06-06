# commands/egg_ingredient_command.rb
# encoding: UTF-8

class EggIngredientCommand
  # 정상적인 식재료 (50개)
  NORMAL_INGREDIENTS = [
    "체다 치즈",
    "모차렐라 치즈",
    "파마산 치즈",
    "고다 치즈",
    "무염 버터",
    "발효 버터",
    "신선한 생크림",
    "우유",
    "베이컨",
    "햄",
    "소시지",
    "양파",
    "적양파",
    "쪽파",
    "대파",
    "마늘",
    "방울토마토",
    "토마토",
    "양송이버섯",
    "새송이버섯",
    "표고버섯",
    "시금치",
    "케일",
    "루꼴라",
    "파프리카",
    "청양고추",
    "피망",
    "당근",
    "감자",
    "고구마",
    "애호박",
    "브로콜리",
    "아스파라거스",
    "옥수수",
    "완두콩",
    "흑후추",
    "소금",
    "설탕",
    "올리브오일",
    "참기름",
    "케첩",
    "마요네즈",
    "머스타드",
    "간장",
    "식초",
    "바질",
    "파슬리",
    "로즈마리",
    "타임",
    "오레가노"
  ]

  # 이상한 식재료 (50개)
  WEIRD_INGREDIENTS = [
    "말린 명태",
    "거미줄",
    "복어",
    "해삼",
    "멍게",
    "불가사리",
    "해파리",
    "말린 오징어",
    "말린 멸치",
    "말린 새우",
    "개구리 다리",
    "달팽이",
    "메뚜기",
    "번데기",
    "두리안",
    "여주",
    "낫토",
    "청국장",
    "바나나 껍질",
    "수박 껍질",
    "귤 껍질",
    "레몬 껍질",
    "쓴 약초",
    "인삼 뿌리",
    "감초",
    "도라지 뿌리",
    "연근",
    "우엉",
    "민들레 잎",
    "쑥",
    "미역",
    "다시마",
    "파래",
    "김",
    "솔잎",
    "소나무 껍질",
    "솔방울",
    "도토리",
    "은행",
    "밤 껍질",
    "호두 껍질",
    "땅콩 껍질",
    "옥수수 수염",
    "생강 껍질",
    "마늘 껍질",
    "양파 껍질",
    "무청",
    "배추 겉잎",
    "고추씨",
    "깨끗한 흙"
  ]

  def initialize(student_id, sheet_manager)
    @student_id = student_id.gsub('@', '')
    @sheet_manager = sheet_manager
  end

  def execute
    puts "[EGG_INGREDIENT] START user=#{@student_id}"
    
    player = @sheet_manager.find_user(@student_id)
    unless player
      return "@#{@student_id} 아직 학적부에 등록되지 않았어요."
    end

    current_items = player[:items].to_s.split(",").map(&:strip).reject(&:empty?)

    # 100개 중 랜덤 선택 (50:50 비율)
    all_ingredients = NORMAL_INGREDIENTS + WEIRD_INGREDIENTS
    ingredient = all_ingredients.sample

    # 인벤토리에 추가
    current_items << ingredient
    new_items = current_items.join(",")

    @sheet_manager.update_user(@student_id, {
      items: new_items
    })

    message = "@#{@student_id} 계란요리 시합 재료를 뽑았어요!\n\n"
    message += "#{ingredient}\n\n"
    message += "주머니에 추가되었어요!"
    
    puts "[EGG_INGREDIENT] SUCCESS: #{ingredient}"
    return message
  end
end
