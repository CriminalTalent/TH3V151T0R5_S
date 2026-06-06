# encoding: UTF-8
require 'time'
require 'cgi'

require_relative 'commands/buy_command'
require_relative 'commands/sell_command'
require_relative 'commands/transfer_item_command'
require_relative 'commands/transfer_galleons_command'
require_relative 'commands/use_item_command'
require_relative 'commands/pouch_command'
require_relative 'commands/tarot_command'
require_relative 'commands/bet_command'
require_relative 'commands/dice_command'
require_relative 'commands/coin_command'
require_relative 'commands/yn_command'
require_relative 'commands/egg_ingredient_command'

# ============================================
# command_parser.rb
# 상점봇 명령어 파서 및 분기 처리 (TAROT 78장 완전판)
# ============================================

module CommandParser
  # ------------------------------
  # 쿨타임 저장소 (유저+명령어 단위)
  # ------------------------------
  @@last_reply_at = {}
  @@cooldown_mutex = Mutex.new

  # ------------------------------
  # 명령어별 쿨타임(초)
  # ------------------------------
  COOLDOWN_BY_CMD = {
    buy: 10,
    sell: 5,
    transfer_galleons: 10,
    transfer_item: 10,
    use_item: 5,
    pouch: 5,
    tarot: 30,
    bet: 10,
    egg_ingredient: 10,

    # 즉시실행
    dice: 0,
    coin: 0,
    yn: 0
  }.freeze

  # -----------------------------------
  # TAROT 78장 데이터
  # -----------------------------------
  TAROT_DATA = {
    # --- Major Arcana (22) ---
    "THE FOOL" => "순수한 마음으로 새로운 모험을 시작할 때라네. 망설이지 말고 발을 내딛게, 학생.",
    "THE MAGICIAN" => "지금이 바로 손재주를 발휘할 때라네. 가진 걸 믿고 써먹어보게.",
    "THE HIGH PRIESTESS" => "겉보다 속을 봐야 할 때라네. 조용히 듣고 관찰하게.",
    "THE EMPRESS" => "풍요로움이 넘치는 시기라네. 마음을 열고 주변과 나누게.",
    "THE EMPEROR" => "책임감 있게 자리를 지켜야 할 때라네. 네가 중심을 잡아야 하지.",
    "THE HIEROPHANT" => "배움에는 끝이 없다네. 전통 속에서 해답을 찾아보게.",
    "THE LOVERS" => "선택의 순간이라네. 마음이 진짜 원하는 걸 따라가게.",
    "THE CHARIOT" => "의지와 집중으로 돌파해야 할 때라네. 흔들리지 말게, 학생.",
    "STRENGTH" => "진짜 힘은 온화함에서 나온다네. 조급하지 않게 마음을 다스리게.",
    "THE HERMIT" => "혼자 있는 시간 속에 답이 있다네. 등불을 켜고 내면을 들여다보게.",
    "WHEEL OF FORTUNE" => "운명의 수레바퀴가 돈다네. 이번엔 바람이 어디로 불지 모르지.",
    "JUSTICE" => "공정하게 판단해야 할 때라네. 감정은 잠시 접어두게.",
    "THE HANGED MAN" => "잠시 멈춰보게. 다른 각도에서 보면 세상이 달라진다네.",
    "DEATH" => "끝이 있어야 새 시작이 있지. 두려워 말고 털고 일어나게.",
    "TEMPERANCE" => "균형을 잡아야 한다네. 너무 많지도 적지도 않게 조절하게.",
    "THE DEVIL" => "유혹이 다가오네, 학생. 하지만 스스로 묶이지 말게.",
    "THE TOWER" => "모래성처럼 무너질 수도 있지. 하지만 잔해 위에서 새 출발을 하게.",
    "THE STAR" => "별빛이 아직 남았구먼. 희망을 잃지 말게.",
    "THE MOON" => "착각과 진실이 뒤섞여 있네. 확신은 잠시 미뤄두게.",
    "THE SUN" => "햇살이 쨍하구먼. 지금은 웃어도 좋은 때라네.",
    "JUDGEMENT" => "심판의 나팔이 울린다네. 과거를 정리하고 다시 일어설 차례라네.",
    "THE WORLD" => "모든 것이 제자리에 돌아왔구먼. 완성의 기쁨을 누리게, 학생.",

    # --- Wands (불, 창조, 열정) ---
    "ACE OF WANDS" => "불씨가 피어오르네. 새 아이디어가 네 손끝에 깃들었다네.",
    "TWO OF WANDS" => "앞날을 내다보게. 결정의 시기라네, 학생.",
    "THREE OF WANDS" => "기다림의 끝이 다가오네. 준비한 만큼 보답을 받을 걸세.",
    "FOUR OF WANDS" => "축하할 일이 있구먼. 작은 성취를 즐기게.",
    "FIVE OF WANDS" => "의견 충돌이 있겠네. 하지만 경쟁 속에서 성장한다네.",
    "SIX OF WANDS" => "승리의 행진이라네. 모두가 자네를 주목하고 있네.",
    "SEVEN OF WANDS" => "수세에 몰렸구먼. 그래도 물러서지 말게, 끝까지 버티는 거야.",
    "EIGHT OF WANDS" => "빠른 변화가 몰려온다네. 행동할 때라네.",
    "NINE OF WANDS" => "피곤하겠지만 아직 끝이 아니네. 마지막까지 지켜내게.",
    "TEN OF WANDS" => "너무 많은 짐을 짊어졌구먼. 잠시 내려놓을 줄도 알아야지.",
    "PAGE OF WANDS" => "열정적인 전령이라네. 새로운 일에 도전할 마음이 가득하네.",
    "KNIGHT OF WANDS" => "불같은 추진력이 느껴지네. 하지만 성급함은 경계하게.",
    "QUEEN OF WANDS" => "당당하고 매력적인 인물이로군. 자신감을 잃지 말게.",
    "KING OF WANDS" => "리더십이 필요한 순간이라네. 결단하고 이끌어야 할 때라네.",

    # --- Cups (물, 감정, 사랑) ---
    "ACE OF CUPS" => "감정의 샘이 터졌구먼. 사랑이 피어날 조짐이라네.",
    "TWO OF CUPS" => "좋은 인연이 찾아온다네. 상호 존중이 열쇠일세.",
    "THREE OF CUPS" => "함께 웃을 일이 있구먼. 친구들과 기쁨을 나누게.",
    "FOUR OF CUPS" => "마음이 지쳐있네. 지금은 잠시 쉬어가도 좋네.",
    "FIVE OF CUPS" => "잃은 것만 보이네? 남은 컵도 바라보게, 학생.",
    "SIX OF CUPS" => "추억이 향기를 풍기네. 과거의 정이 다시 스며든다네.",
    "SEVEN OF CUPS" => "환상 속에서 헤매지 말게. 진짜 원하는 걸 고르게.",
    "EIGHT OF CUPS" => "이제 미련을 두지 말게. 떠나야 할 때라네.",
    "NINE OF CUPS" => "소원이 이루어진다네. 마음껏 누려보게.",
    "TEN OF CUPS" => "평화와 조화가 찾아오네. 진심으로 웃을 수 있을 때라네.",
    "PAGE OF CUPS" => "감성이 풍부하구먼. 예술적인 영감이 찾아오고 있다네.",
    "KNIGHT OF CUPS" => "낭만적인 제안이 다가오네. 하지만 현실도 잊지 말게.",
    "QUEEN OF CUPS" => "따뜻하고 이해심 깊은 사람이로군. 감정의 파도 속에서도 중심을 잡게.",
    "KING OF CUPS" => "감정의 주인이라네. 냉정함과 따뜻함을 함께 품게.",

    # --- Swords (공기, 사고, 진실, 갈등) ---
    "ACE OF SWORDS" => "진실이 번쩍하네. 이성의 칼로 길을 열게.",
    "TWO OF SWORDS" => "갈림길에서 머뭇거리고 있구먼. 결단이 필요하다네.",
    "THREE OF SWORDS" => "가슴이 저미는 아픔이 있겠네. 하지만 진실은 언제나 통증을 동반하지.",
    "FOUR OF SWORDS" => "지친 정신을 쉬게 하게. 잠시 휴식이 약이라네.",
    "FIVE OF SWORDS" => "이긴 듯 보여도 상처가 남는 싸움이라네. 현명하게 물러설 줄도 알아야지.",
    "SIX OF SWORDS" => "고통을 떠나 평온을 찾아가는 여정이라네.",
    "SEVEN OF SWORDS" => "누군가 속임수를 쓰고 있구먼. 눈을 부릅뜨게.",
    "EIGHT OF SWORDS" => "스스로 묶여있네. 하지만 그 끈은 자네 손에 있다네.",
    "NINE OF SWORDS" => "불안과 후회가 밤을 지배하겠네. 하지만 새벽은 반드시 오지.",
    "TEN OF SWORDS" => "끝장 같지만, 다시 일어설 기회라네. 완전한 끝은 없지.",
    "PAGE OF SWORDS" => "호기심 많은 학생이로군. 지식을 향한 갈증이 느껴진다네.",
    "KNIGHT OF SWORDS" => "단호하고 빠른 자라네. 하지만 무모함은 금물이지.",
    "QUEEN OF SWORDS" => "이성적이고 냉철한 인물이로군. 감정보다 진실을 중시하네.",
    "KING OF SWORDS" => "법과 논리의 상징이라네. 명확한 판단으로 일처리하게.",

    # --- Pentacles (땅, 현실, 물질, 노력) ---
    "ACE OF PENTACLES" => "기회가 눈앞에 있네. 현실적인 성취가 시작된다네.",
    "TWO OF PENTACLES" => "균형이 필요하네. juggling을 잘해야 한다네, 학생.",
    "THREE OF PENTACLES" => "협력의 힘이 중요하네. 함께 일할 때 결과가 좋다네.",
    "FOUR OF PENTACLES" => "손에 쥔 걸 너무 꽉 쥐지 말게. 때로는 나눔이 더 큰 이익을 부르네.",
    "FIVE OF PENTACLES" => "추운 겨울을 걷는 기분이겠네. 하지만 도움의 손길이 멀지 않다네.",
    "SIX OF PENTACLES" => "주는 것도, 받는 것도 배움이라네. 균형이 중요하지.",
    "SEVEN OF PENTACLES" => "인내의 시간이라네. 씨를 뿌렸다면 기다릴 줄도 알아야지.",
    "EIGHT OF PENTACLES" => "노력은 결코 배신하지 않네. 꾸준히 다듬게.",
    "NINE OF PENTACLES" => "자립의 시기라네. 스스로 이룬 것의 열매를 맛보게.",
    "TEN OF PENTACLES" => "유산과 번영이 흐르네. 가족, 안정, 전통이 중심이 된다네.",
    "PAGE OF PENTACLES" => "배움을 즐기는 학생이로군. 새로운 기술이 자랄 때라네.",
    "KNIGHT OF PENTACLES" => "성실하고 꾸준한 인물이네. 느리지만 끝까지 간다네.",
    "QUEEN OF PENTACLES" => "현실적이면서 따뜻한 사람이라네. 돌봄 속에서 풍요가 자라지.",
    "KING OF PENTACLES" => "성공과 책임의 상징이라네. 자네의 노력이 결실을 맺을 때라네."
  }.freeze

  # -----------------------------------
  # (내부) 쿨타임 체크/기록
  # -----------------------------------
  def self.cooldown_seconds_for(cmd_key)
    COOLDOWN_BY_CMD[cmd_key] || 10
  end

  def self.cooldown_key(acct, cmd_key)
    "#{acct}::#{cmd_key}"
  end

  def self.cooldown_blocked?(acct, cmd_key)
    cd = cooldown_seconds_for(cmd_key)
    return false if cd.to_i <= 0

    now = Time.now
    key = cooldown_key(acct, cmd_key)

    @@cooldown_mutex.synchronize do
      last = @@last_reply_at[key]
      if last && (now - last) < cd
        diff = (now - last).round(1)
        puts "[REPLY-SKIP] @#{acct} cmd=#{cmd_key} #{diff}s 이내 재요청 → 스킵(쿨타임 #{cd}s)"
        true
      else
        @@last_reply_at[key] = now
        false
      end
    end
  end

  # -----------------------------------
  # 유저별 답글 헬퍼
  # -----------------------------------
  def self.safe_reply(mastodon_client, notification, acct, text, cmd_key: :default, visibility: "unlisted")
    return if text.nil? || text.to_s.strip.empty?

    status_id = notification.is_a?(Hash) ? notification.dig("status", "id") : nil
    unless status_id
      puts "[REPLY-SKIP] @#{acct} status_id를 찾지 못함 → 답글 스킵"
      return
    end

    if cooldown_blocked?(acct, cmd_key)
      return
    end

    begin
      mastodon_client.post_status(text, reply_to_id: status_id, visibility: visibility)
    rescue => e
      puts "[REPLY-ERROR] @#{acct} 답글 중 에러: #{e.class} - #{e.message}"
    end
  end

  # -----------------------------------
  # 메인 파서
  # -----------------------------------
  def self.parse(mastodon_client, sheet_manager, notification)
    begin
      content_raw  = notification.dig("status", "content") || ""
      account_info = notification["account"] || {}
      sender       = account_info["acct"] || ""
      display      = account_info["display_name"].to_s.strip.empty? ? sender : account_info["display_name"].to_s.strip
      content      = clean_html(content_raw)

      puts "[PARSER] from=@#{sender}(#{display})"
      puts "[PARSER] 원본: #{content_raw[0..100]}"
      puts "[PARSER] 정제: #{content}"

      message = nil
      cmd_key = nil

      case content
      when /\[구매\/(.+?)\]/
        item_name = Regexp.last_match(1).to_s.strip
        puts "[PARSER] 구매 명령 감지: #{item_name}"
        cmd_key = :buy
        message = BuyCommand.new(content, sender, sheet_manager).execute
        if message == :player_not_found
          puts "[BUY] ERROR: player not found (@#{sender})"
          return
        end

      when /\[판매\/(.+?)\]/
        item_name = Regexp.last_match(1).to_s.strip
        puts "[PARSER] 판매 명령 감지: #{item_name}"
        cmd_key = :sell
        message = SellCommand.new(sender, item_name, sheet_manager).execute

      when /\[양도\/갈레온\/(\d+)\/@(.+?)\]/i
        amount = Regexp.last_match(1).to_i
        target_acct = Regexp.last_match(2).to_s.strip.split('@').first
        puts "[PARSER] 갈레온 양도: #{amount}G → @#{target_acct}"
        cmd_key = :transfer_galleons
        message = TransferGalleonsCommand.new(sender, target_acct, amount, sheet_manager).execute

      when /\[양도\/(.+?)\/@(.+?)\]/
        item_name   = Regexp.last_match(1).to_s.strip
        target_acct = Regexp.last_match(2).to_s.strip.split('@').first
        puts "[PARSER] 아이템 양도: #{item_name} → @#{target_acct}"
        cmd_key = :transfer_item
        message = TransferItemCommand.new(sender, target_acct, item_name, sheet_manager).execute

      when /\[사용\/(.+?)\]/
        item_name = Regexp.last_match(1).to_s.strip
        puts "[PARSER] 사용 명령 감지: #{item_name}"
        cmd_key = :use_item
        message = UseItemCommand.new(sender, item_name, sheet_manager).execute

      when /\[주머니\]/
        puts "[PARSER] 주머니 명령 감지"
        cmd_key = :pouch
        # 주머니는 스레드 처리가 필요하므로 직접 실행
        PouchCommand.new(sender, sheet_manager, mastodon_client, notification).execute
        return

      when /\[타로\]/
        puts "[PARSER] 타로 명령 감지"
        cmd_key = :tarot
        message = TarotCommand.new(sender, TAROT_DATA, sheet_manager).execute

      when /\[베팅\/(\d+)\]/
        amount = Regexp.last_match(1).to_i
        puts "[PARSER] 베팅 명령 감지: #{amount}G"
        cmd_key = :bet
        message = BetCommand.new(sender, amount, sheet_manager).execute

      when /\[계란재료\]/
        puts "[PARSER] 계란재료 명령 감지"
        cmd_key = :egg_ingredient
        message = EggIngredientCommand.new(sender, sheet_manager).execute

      # ===== 기존 즉시실행 명령어 =====
      when /\[주사위|d\d+|\d+d\]/i
        puts "[PARSER] 주사위 명령 감지"
        DiceCommand.run(mastodon_client, notification)
        return

      when /\[동전|coin\]/i
        puts "[PARSER] 동전 명령 감지"
        CoinCommand.run(mastodon_client, notification)
        return

      when /\[YN\]/i
        puts "[PARSER] YN 명령 감지"
        YnCommand.run(mastodon_client, notification)
        return

      else
        puts "[PARSER] 명령 없음"
        return
      end

      # 공통 답글 처리
      if message && message != :player_not_found
        puts "[PARSER] 답글 전송 준비(cmd=#{cmd_key}): #{message.to_s[0..50]}..."
        safe_reply(mastodon_client, notification, sender, message, cmd_key: (cmd_key || :default))
      end

    rescue => e
      puts "[에러] 명령어 처리 실패: #{e.message}"
      puts "  ↳ #{e.backtrace.first(5).join("\n  ↳ ")}"
    end
  end

  # -----------------------------------
  # HTML 정제
  # -----------------------------------
  def self.clean_html(html)
    return "" if html.nil?

    s = html.to_s

    s = s.gsub(/<br\s*\/?>/i, "\n")
         .gsub(/<\/p\s*>/i, "\n")
         .gsub(/<p[^>]*>/i, "")

    s = s.gsub(/<[^>]*>/, "")

    begin
      s = CGI.unescapeHTML(s)
    rescue
    end

    s = s.gsub("\u00A0", " ")
         .gsub(/[ \t]+\n/, "\n")
         .gsub(/\n{3,}/, "\n\n")
         .strip

    s
  end
end
