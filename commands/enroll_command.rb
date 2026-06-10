# commands/enroll_command.rb
# encoding: UTF-8

class EnrollCommand
  INITIAL_CREDITS     = 0
  INITIAL_STAT_POINTS = 10

  def initialize(sheet_manager, mastodon_client, sender, name, status)
    @sheet_manager   = sheet_manager
    @mastodon_client = mastodon_client
    @sender          = sender.gsub('@', '')
    @name            = name
    @status          = status
  end

  def execute
    if @sheet_manager.find_user(@sender)
      @mastodon_client.reply(
        "@#{@sender} 이미 등록된 계정입니다.",
        @status['id']
      )
      return
    end

    # 사용자 시트 등록
    # A=ID / B=이름 / C=크레딧 / D=아이템 / E=메모
    # F=마지막베팅일 / G=오늘베팅횟수 / H=마지막타로일
    # I=누적툿수 / J=정산기준툿수 / K=스탯포인트잔여
    user_row = [
      @sender,
      @name,
      INITIAL_CREDITS,
      '',
      '',
      '',
      0,
      '',
      0,
      0,
      INITIAL_STAT_POINTS
    ]
    @sheet_manager.append('사용자', user_row)

    # 스탯 시트 등록
    # A=ID / B=이름 / C=건강(50) / D=마법능력(10) / E=인내(10)
    # F=속도(0) / G=기술(0) / H=행운(5)
    stat_row = [
      @sender,
      @name,
      50,
      10,
      10,
      0,
      0,
      5
    ]
    @sheet_manager.append('스탯', stat_row)

    puts "[등록] @#{@sender} (#{@name}) 등록 완료"

    @mastodon_client.reply(
      "@#{@sender} 등록이 완료되었습니다.\n" \
      "초기 스탯 포인트 #{INITIAL_STAT_POINTS}포인트가 지급되었습니다.\n" \
      "[소지품] 명령어로 현재 상태를 확인할 수 있습니다.",
      @status['id']
    )
  rescue => e
    puts "[에러] 등록 처리 실패: #{e.message}"
    @mastodon_client.reply(
      "@#{@sender} 등록 처리 중 오류가 발생했습니다.",
      @status['id']
    )
  end
end
