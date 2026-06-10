# sheet_manager.rb
# encoding: UTF-8
require 'google/apis/sheets_v4'

class SheetManager
  USERS_SHEET  = '사용자'.freeze
  ITEMS_SHEET  = '아이템'.freeze
  STATS_SHEET  = '스탯'.freeze

  # 사용자 시트 컬럼
  # A: ID / B: 이름 / C: 크레딧 / D: 아이템 / E: 메모
  # F: 마지막베팅일 / G: 오늘베팅횟수 / H: 마지막타로일
  # I: 누적툿수 / J: 정산기준툿수 / K: 스탯포인트잔여

  # 스탯 시트 컬럼
  # A: ID / B: 이름 / C: 건강(기본50) / D: 마법능력(기본10)
  # E: 인내(기본10) / F: 속도(기본0) / G: 기술(기본0) / H: 행운(기본5)

  STAT_NAMES = {
    '건강'    => { col: 'C', default: 50 },
    '마법능력' => { col: 'D', default: 10 },
    '인내'    => { col: 'E', default: 10 },
    '속도'    => { col: 'F', default: 0  },
    '기술'    => { col: 'G', default: 0  },
    '행운'    => { col: 'H', default: 5  }
  }.freeze

  STAT_POINT_COST = 10  # 스탯 1포인트 구매 비용(크레딧)

  def initialize(service, sheet_id)
    @service  = service
    @sheet_id = sheet_id
  end

  # ──────────────────────────────────────────────
  # 기본 I/O
  # ──────────────────────────────────────────────
  def read(sheet, range = 'A:Z')
    @service.get_spreadsheet_values(@sheet_id, "#{sheet}!#{range}").values || []
  rescue
    []
  end

  def write(sheet, range, values)
    body = Google::Apis::SheetsV4::ValueRange.new(values: values)
    @service.update_spreadsheet_value(
      @sheet_id, "#{sheet}!#{range}", body,
      value_input_option: 'USER_ENTERED'
    )
  end

  def append(sheet, row)
    body = Google::Apis::SheetsV4::ValueRange.new(values: [row])
    @service.append_spreadsheet_value(
      @sheet_id, "#{sheet}!A:Z", body,
      value_input_option: 'USER_ENTERED'
    )
  end

  # 범용 (기존 코드 호환)
  def read_values(range)
    @service.get_spreadsheet_values(@sheet_id, range).values || []
  rescue
    []
  end

  def update_values(range, values)
    body = Google::Apis::SheetsV4::ValueRange.new(values: values)
    @service.update_spreadsheet_value(
      @sheet_id, range, body,
      value_input_option: 'USER_ENTERED'
    )
  end

  # ──────────────────────────────────────────────
  # 아이템
  # ──────────────────────────────────────────────
  # 아이템 시트: A=이름 / B=설명 / C=가격 / D=판매여부 / E=사용가능여부
  def find_item(item_name)
    rows = read(ITEMS_SHEET, 'A:E')
    rows[1..].each do |row|
      next unless row[0]&.strip == item_name.to_s.strip
      return {
        name:     row[0],
        description: row[1],
        price:    row[2].to_i,
        sellable: row[3].to_s.strip.upcase == 'TRUE' || row[3] == true,
        usable:   row[4].to_s.strip.upcase == 'TRUE' || row[4] == true
      }
    end
    nil
  end

  # ──────────────────────────────────────────────
  # 사용자
  # ──────────────────────────────────────────────
  def find_user(acct)
    acct = acct.to_s.gsub('@', '').strip
    rows = read(USERS_SHEET, 'A:K')
    rows[1..].each_with_index do |row, i|
      next unless row[0]&.gsub('@', '')&.strip == acct
      return build_user(row, i + 2)
    end
    nil
  end

  def update_user(acct, attrs)
    acct = acct.to_s.gsub('@', '').strip
    rows = read(USERS_SHEET, 'A:K')
    rows[1..].each_with_index do |row, i|
      next unless row[0]&.gsub('@', '')&.strip == acct
      row_num = i + 2
      col_map = {
        credits:        'C',
        items:          'D',
        memo:           'E',
        last_bet_date:  'F',
        today_bet_count:'G',
        last_tarot_date:'H',
        toot_count:     'I',
        toot_baseline:  'J',
        stat_points:    'K'
      }
      attrs.each do |key, val|
        col = col_map[key]
        next unless col
        write(USERS_SHEET, "#{col}#{row_num}", [[val]])
      end
      return true
    end
    false
  end

  # ──────────────────────────────────────────────
  # 스탯
  # ──────────────────────────────────────────────
  def find_stats(acct)
    acct = acct.to_s.gsub('@', '').strip
    rows = read(STATS_SHEET, 'A:H')
    rows[1..].each_with_index do |row, i|
      next unless row[0]&.gsub('@', '')&.strip == acct
      return build_stats(row, i + 2)
    end
    nil
  end

  def update_stat(acct, stat_name, new_val)
    acct = acct.to_s.gsub('@', '').strip
    info = STAT_NAMES[stat_name]
    return false unless info
    rows = read(STATS_SHEET, 'A:H')
    rows[1..].each_with_index do |row, i|
      next unless row[0]&.gsub('@', '')&.strip == acct
      row_num = i + 2
      write(STATS_SHEET, "#{info[:col]}#{row_num}", [[new_val]])
      return true
    end
    false
  end

  # ──────────────────────────────────────────────
  # 툿 카운트 정산 (자정 스케줄러 호출)
  # ──────────────────────────────────────────────
  # toot_count(I열): 마스토돈 API로 갱신한 현재 누적 툿 수
  # toot_baseline(J열): 마지막 정산 시점의 누적 툿 수
  # 차이 // 100 * 15 크레딧 지급 후 baseline 갱신
  def settle_toot_credits(acct, current_toot_count)
    user = find_user(acct)
    return unless user

    baseline = user[:toot_baseline]
    diff     = current_toot_count - baseline
    return if diff < 100

    earned_units = diff / 100
    earned       = earned_units * 15
    new_baseline = baseline + (earned_units * 100)
    new_credits  = user[:credits] + earned

    update_user(acct, {
      credits:       new_credits,
      toot_count:    current_toot_count,
      toot_baseline: new_baseline
    })

    puts "[툿정산] @#{acct}: +#{earned}크레딧 (#{diff}툿, #{earned_units}단위)"
    { earned: earned, units: earned_units }
  end

  # toot_count만 갱신 (정산 없이 기록만)
  def update_toot_count(acct, count)
    update_user(acct, { toot_count: count })
  end

  # 모든 사용자 목록 반환
  def all_users
    rows = read(USERS_SHEET, 'A:K')
    result = []
    rows[1..].each_with_index do |row, i|
      next if row.nil? || row[0].nil?
      result << build_user(row, i + 2)
    end
    result
  end

  private

  def build_user(row, row_num)
    {
      row_num:          row_num,
      id:               row[0].to_s.strip,
      name:             row[1].to_s.strip,
      credits:          (row[2] || 0).to_i,
      items:            row[3].to_s,
      memo:             row[4].to_s,
      last_bet_date:    row[5].to_s,
      today_bet_count:  (row[6] || 0).to_i,
      last_tarot_date:  row[7].to_s,
      toot_count:       (row[8] || 0).to_i,
      toot_baseline:    (row[9] || 0).to_i,
      stat_points:      (row[10] || 0).to_i
    }
  end

  def build_stats(row, row_num)
    {
      row_num:      row_num,
      id:           row[0].to_s.strip,
      name:         row[1].to_s.strip,
      health:       (row[2] || 50).to_i,   # 건강
      magic:        (row[3] || 10).to_i,   # 마법능력
      endurance:    (row[4] || 10).to_i,   # 인내
      speed:        (row[5] || 0).to_i,    # 속도
      skill:        (row[6] || 0).to_i,    # 기술
      luck:         (row[7] || 5).to_i     # 행운
    }
  end
end
