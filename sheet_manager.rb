# sheet_manager.rb
# encoding: UTF-8

require 'google/apis/sheets_v4'
require 'googleauth'

class SheetManager
  USERS_SHEET     = '사용자'.freeze
  STATS_SHEET     = '스탯'.freeze
  ITEMS_SHEET     = '아이템'.freeze
  HOUSE_SHEET     = '기숙사'.freeze
  PROFESSOR_SHEET = '교수'.freeze
  AUTO_TOOT_SHEET = '자동툿'.freeze
  RECIPE_SHEET    = '레시피'.freeze
  LOG_SHEET       = '로그'.freeze

  MAX_RETRIES = 4

  def initialize(service, sheet_id)
    @service  = service
    @sheet_id = sheet_id
  end

  # Google Sheets API 쿼터 초과 시 지수 백오프로 재시도한다.
  #
  # 최초 요청 실패 후:
  # 1회차: 2초
  # 2회차: 4초
  # 3회차: 8초
  # 4회차: 16초
  def with_retry
    retries = 0

    begin
      yield
    rescue Google::Apis::RateLimitError => e
      retries += 1
      raise if retries > MAX_RETRIES

      wait_seconds = 2**retries

      puts(
        "[쿼터 초과] #{wait_seconds}초 후 재시도 " \
        "(#{retries}/#{MAX_RETRIES}): #{e.message}"
      )

      sleep wait_seconds
      retry
    rescue Google::Apis::Error => e
      unless resource_exhausted_error?(e)
        raise
      end

      retries += 1
      raise if retries > MAX_RETRIES

      wait_seconds = 2**retries

      puts(
        "[쿼터 초과] #{wait_seconds}초 후 재시도 " \
        "(#{retries}/#{MAX_RETRIES}): #{e.message}"
      )

      sleep wait_seconds
      retry
    end
  end

  def read(sheet, range = 'A:Z')
    with_retry do
      response = @service.get_spreadsheet_values(
        @sheet_id,
        "#{sheet}!#{range}"
      )

      response.values || []
    end
  rescue => e
    puts "[시트 읽기 오류] #{e.message}"
    []
  end

  def write(sheet, range, values)
    with_retry do
      body = Google::Apis::SheetsV4::ValueRange.new(
        values: values
      )

      @service.update_spreadsheet_value(
        @sheet_id,
        "#{sheet}!#{range}",
        body,
        value_input_option: 'USER_ENTERED'
      )
    end

    true
  rescue => e
    puts "[시트 쓰기 오류] #{e.message}"
    false
  end

  # 여러 범위의 값을 Google Sheets API 호출 한 번으로 기록한다.
  #
  # 예:
  # {
  #   "사용자!C2" => 100,
  #   "사용자!D2" => "아이템1,아이템2"
  # }
  def batch_write(range_value_map)
    return false if range_value_map.nil? || range_value_map.empty?

    data = range_value_map.map do |range, value|
      Google::Apis::SheetsV4::ValueRange.new(
        range: range,
        values: [[value]]
      )
    end

    body = Google::Apis::SheetsV4::BatchUpdateValuesRequest.new(
      value_input_option: 'USER_ENTERED',
      data: data
    )

    with_retry do
      @service.batch_update_values(
        @sheet_id,
        body
      )
    end

    true
  rescue => e
    puts "[시트 배치 쓰기 오류] #{e.message}"
    false
  end

  def append(sheet, row)
    with_retry do
      body = Google::Apis::SheetsV4::ValueRange.new(
        values: [row]
      )

      @service.append_spreadsheet_value(
        @sheet_id,
        "#{sheet}!A:Z",
        body,
        value_input_option: 'USER_ENTERED'
      )
    end

    true
  rescue => e
    puts "[시트 추가 오류] #{e.message}"
    false
  end

  def read_values(range)
    with_retry do
      response = @service.get_spreadsheet_values(
        @sheet_id,
        range
      )

      response.values || []
    end
  rescue => e
    puts "[값 읽기 오류] #{e.message}"
    []
  end

  def update_values(range, values)
    with_retry do
      body = Google::Apis::SheetsV4::ValueRange.new(
        values: values
      )

      @service.update_spreadsheet_value(
        @sheet_id,
        range,
        body,
        value_input_option: 'USER_ENTERED'
      )
    end

    true
  rescue => e
    puts "[시트 업데이트 오류] #{e.message}"
    false
  end

  def find_user(acct)
    acct = normalize_acct(acct)
    rows = read(USERS_SHEET, 'A:Z')

    rows[1..].to_a.each_with_index do |row, index|
      next unless normalize_acct(row[0]) == acct

      house = row[4].to_s.strip
      house = find_user_house(acct) if house.empty?

      return {
        row_num:         index + 2,
        id:              row[0].to_s.strip,
        name:            row[1].to_s.strip,
        credits:         (row[2] || 0).to_i,
        items:           row[3].to_s,
        house:           house,
        memo:            row[4].to_s,
        last_bet_date:   row[5].to_s,
        today_bet_count: (row[6] || 0).to_i,
        last_tarot_date: row[7].to_s,
        toot_count:      (row[8] || 0).to_i,
        toot_baseline:   (row[9] || 0).to_i,
        stat_points:     (row[10] || 0).to_i,
        attendance_date: row[11].to_s.strip,
        homework_date:   row[12].to_s.strip
      }
    end

    nil
  rescue => e
    puts "[find_user 오류] #{e.message}"
    nil
  end

  def user_exists?(acct)
    !!find_user(acct)
  end

  # 사용자 시트의 전체 유저 목록
  def all_users
    rows = read(USERS_SHEET, 'A:Z')
    result = []

    rows[1..].to_a.each_with_index do |row, index|
      id = row[0].to_s.strip
      next if id.empty?

      result << {
        row_num:       index + 2,
        id:            id,
        name:          row[1].to_s.strip,
        credits:       (row[2] || 0).to_i,
        toot_count:    (row[8] || 0).to_i,
        toot_baseline: (row[9] || 0).to_i
      }
    end

    result
  rescue => e
    puts "[all_users 오류] #{e.message}"
    []
  end

  # 누적툿수(I열) 기록
  def update_toot_count(acct, count)
    update_user(acct, toot_count: count.to_i)
  end

  # 사용자 ID가 있는 A열만 한 번 읽고,
  # 변경할 모든 셀은 batch_update_values 한 번으로 기록한다.
  def update_user(acct, attrs)
    acct = normalize_acct(acct)

    col_map = {
      credits:         'C',
      items:           'D',
      house:           'E',
      memo:            'E',
      last_bet_date:   'F',
      today_bet_count: 'G',
      last_tarot_date: 'H',
      toot_count:      'I',
      toot_baseline:   'J',
      stat_points:     'K',
      attendance_date: 'L',
      homework_date:   'M'
    }

    # 사용자 전체 데이터를 읽지 않고 ID가 있는 A열만 읽는다.
    rows = read(USERS_SHEET, 'A:A')

    row_index = rows[1..].to_a.find_index do |row|
      normalize_acct(row[0]) == acct
    end

    return false unless row_index

    row_num = row_index + 2
    range_value_map = {}

    attrs.each do |key, value|
      column = col_map[key]
      next unless column

      range_value_map[
        "#{USERS_SHEET}!#{column}#{row_num}"
      ] = value
    end

    return false if range_value_map.empty?

    batch_write(range_value_map)
  rescue => e
    puts "[update_user 오류] #{e.message}"
    false
  end

  def find_stats(acct)
    acct = normalize_acct(acct)
    rows = read(STATS_SHEET, 'A:H')

    rows[1..].to_a.each_with_index do |row, index|
      next unless normalize_acct(row[0]) == acct

      return {
        row_num:   index + 2,
        id:        row[0].to_s.strip,
        name:      row[1].to_s.strip,
        health:    (row[2] || 50).to_i,
        magic:     (row[3] || 10).to_i,
        endurance: (row[4] || 10).to_i,
        speed:     (row[5] || 0).to_i,
        skill:     (row[6] || 0).to_i,
        luck:      (row[7] || 5).to_i
      }
    end

    nil
  rescue => e
    puts "[find_stats 오류] #{e.message}"
    nil
  end

  def update_stat(acct, stat_name, new_val)
    acct = normalize_acct(acct)

    col_map = {
      '건강'     => 'C',
      '마법능력' => 'D',
      '인내'     => 'E',
      '속도'     => 'F',
      '기술'     => 'G',
      '행운'     => 'H'
    }

    column = col_map[stat_name]
    return false unless column

    rows = read(STATS_SHEET, 'A:H')

    rows[1..].to_a.each_with_index do |row, index|
      next unless normalize_acct(row[0]) == acct

      return write(
        STATS_SHEET,
        "#{column}#{index + 2}",
        [[new_val]]
      )
    end

    false
  rescue => e
    puts "[update_stat 오류] #{e.message}"
    false
  end

  def find_item(item_name)
    rows = read(ITEMS_SHEET, 'A:F')
    normalized_item_name = item_name.to_s.strip

    rows[1..].to_a.each do |row|
      next unless row[0].to_s.strip == normalized_item_name

      return {
        name:        row[0],
        description: row[1],
        price:       row[2].to_i,
        raw_price:   row[2].to_s.strip,
        sellable:    boolean_true?(row[3]),
        usable:      boolean_true?(row[4]),
        use_message: row[5].to_s.strip
      }
    end

    nil
  rescue => e
    puts "[find_item 오류] #{e.message}"
    nil
  end

  def get_items(acct)
    user = find_user(acct)
    return [] unless user

    user[:items]
      .to_s
      .split(',')
      .map(&:strip)
      .reject(&:empty?)
  end

  def set_items(acct, items_array)
    update_user(
      acct,
      items: items_array.join(',')
    )
  end

  def user_has_item?(acct, item_name)
    normalized_item_name = item_name.to_s.strip

    get_items(acct).any? do |item|
      item.to_s.strip == normalized_item_name
    end
  end

  def get_recipes
    rows = read(RECIPE_SHEET, 'A:D')
    return [] if rows.empty?

    rows[1..].to_a.reject do |row|
      row.nil? || row[0].to_s.strip.empty?
    end
  rescue => e
    puts "[get_recipes 오류] #{e.message}"
    []
  end

  def find_user_house(acct)
    acct = normalize_acct(acct)

    user_rows = read(USERS_SHEET, 'A:Z')

    unless user_rows.empty?
      header = user_rows[0] || []

      house_col = header.index do |heading|
        heading.to_s.strip == '기숙사'
      end

      house_col ||= 4

      user_rows[1..].to_a.each do |row|
        next unless normalize_acct(row[0]) == acct

        return row[house_col].to_s.strip
      end
    end

    rows = read(STATS_SHEET, 'A:Z')
    header = rows[0] || []

    house_col = header.index do |heading|
      heading.to_s.strip == '기숙사'
    end

    return '' unless house_col

    rows[1..].to_a.each do |row|
      next unless normalize_acct(row[0]) == acct

      return row[house_col].to_s.strip
    end

    ''
  rescue => e
    puts "[find_user_house 오류] #{e.message}"
    ''
  end

  def get_house_credits(house_name)
    rows = read(HOUSE_SHEET, 'A:B')
    normalized_house_name = house_name.to_s.strip

    rows[1..].to_a.each do |row|
      next unless row[0].to_s.strip == normalized_house_name

      return (row[1] || 0).to_i
    end

    0
  rescue => e
    puts "[get_house_credits 오류] #{e.message}"
    0
  end

  def add_house_credits(house_name, amount)
    rows = read(HOUSE_SHEET, 'A:B')
    normalized_house_name = house_name.to_s.strip
    rows[1..].to_a.each_with_index do |row, index|
      next unless row[0].to_s.strip == normalized_house_name
      current_score = (row[1] || 0).to_i
      new_score = current_score + amount.to_i
      success = write(
        HOUSE_SHEET,
        "B#{index + 2}",
        [[new_score]]
      )
      return false unless success
      sleep 0.5
      verify_rows = read(HOUSE_SHEET, 'A:B')
      verify_rows[1..].to_a.each_with_index do |vrow, vidx|
        if vrow[0].to_s.strip == normalized_house_name
          verified_score = (vrow[1] || 0).to_i
          log_house_score(normalized_house_name, amount, verified_score)
          return verified_score
        end
      end
      log_house_score(normalized_house_name, amount, new_score)
      return new_score
    end
    nil
  rescue => e
    puts "[add_house_credits 오류] #{e.message}"
    nil
  end

  def auto_push_enabled?(key:)
    rows = read(PROFESSOR_SHEET, 'A:Z')
    return false if rows.empty?

    header = rows[0] || []
    values = rows[1] || []

    index = header.index do |heading|
      heading.to_s.strip == key.to_s.strip
    end

    return false unless index

    boolean_true?(values[index])
  rescue => e
    puts "[auto_push_enabled? 오류] #{e.message}"
    false
  end

  def load_auto_toots
    rows = read(AUTO_TOOT_SHEET, 'A:C')
    result = []

    rows[1..].to_a.each do |row|
      next if row.nil?
      next if row[2].nil?
      next if row[2].to_s.strip.empty?

      enabled = boolean_true?(row[0])
      time = row[1].to_s.strip
      content = row[2].to_s.strip

      next unless enabled
      next if time.empty?

      result << {
        time: time,
        content: content
      }
    end

    result
  rescue => e
    puts "[load_auto_toots 오류] #{e.message}"
    []
  end

  # 100툿당 15크레딧 정산
  # 정산 시 { earned:, units: } 해시 반환, 정산 대상 아니면 nil
  def settle_toot_credits(acct, current_toot_count)
    user = find_user(acct)
    return nil unless user

    current_toot_count = current_toot_count.to_i
    baseline = user[:toot_baseline].to_i
    difference = current_toot_count - baseline

    return nil if difference < 100

    units = difference / 100
    earned = units * 15
    new_baseline = baseline + (units * 100)

    updated = update_user(
      acct,
      credits: user[:credits] + earned,
      toot_count: current_toot_count,
      toot_baseline: new_baseline
    )

    return nil unless updated

    { earned: earned, units: units }
  rescue => e
    puts "[settle_toot_credits 오류] #{e.message}"
    nil
  end

  private

  def normalize_acct(acct)
    acct.to_s.gsub('@', '').strip
  end

  def boolean_true?(value)
    value == true || value.to_s.strip.upcase == 'TRUE'
  end

  def resource_exhausted_error?(error)
    message = error.message.to_s
    body = error.respond_to?(:body) ? error.body.to_s : ''

    message.include?('RESOURCE_EXHAUSTED') ||
      body.include?('RESOURCE_EXHAUSTED') ||
      message.include?('Quota exceeded') ||
      body.include?('Quota exceeded')
  end
end

# ─────────────────────────────────────────────
# 이미지URL / 현재건강 지원 (기존 메서드 재정의)
# ─────────────────────────────────────────────
class SheetManager
  def find_item(item_name)
    rows = read(ITEMS_SHEET, 'A:G')
    rows[1..].to_a.each do |row|
      next unless row[0]&.strip == item_name.to_s.strip
      return {
        name:        row[0],
        description: row[1],
        price:       row[2].to_i,
        raw_price:   row[2].to_s.strip,
        sellable:    row[3].to_s.strip.upcase == 'TRUE' || row[3] == true,
        usable:      row[4].to_s.strip.upcase == 'TRUE' || row[4] == true,
        use_message: row[5].to_s.strip,
        image_url:   row[6].to_s.strip
      }
    end
    nil
  end

  def find_stats(acct)
    acct = acct.to_s.gsub('@', '').strip
    rows = read(STATS_SHEET, 'A:I')
    rows[1..].to_a.each_with_index do |row, i|
      next unless row[0]&.gsub('@', '')&.strip == acct
      health = (row[2] || 50).to_i
      current_raw = row[8].to_s.strip
      return {
        row_num:        i + 2,
        id:             row[0].to_s.strip,
        name:           row[1].to_s.strip,
        health:         health,
        magic:          (row[3] || 10).to_i,
        endurance:      (row[4] || 10).to_i,
        speed:          (row[5] || 0).to_i,
        skill:          (row[6] || 0).to_i,
        luck:           (row[7] || 5).to_i,
        current_health: current_raw.empty? ? health : current_raw.to_i
      }
    end
    nil
  end

  def update_stat(acct, stat_name, new_val)
    acct = acct.to_s.gsub('@', '').strip
    col_map = {
      '건강'     => 'C', '마법능력' => 'D', '인내' => 'E',
      '속도'     => 'F', '기술'     => 'G', '행운' => 'H',
      '현재건강' => 'I'
    }
    col = col_map[stat_name]
    return false unless col
    rows = read(STATS_SHEET, 'A:I')
    rows[1..].to_a.each_with_index do |row, i|
      next unless row[0]&.gsub('@', '')&.strip == acct
      write(STATS_SHEET, "#{col}#{i + 2}", [[new_val]])
      return true
    end
    false
  end
end

# ─────────────────────────────────────────────
# 스탯 시트 컬럼 재배치 반영
# E=건강(현재건강) / K=최대건강 (기존 메서드 재정의)
# ─────────────────────────────────────────────
class SheetManager
  def find_stats(acct)
    acct = acct.to_s.gsub('@', '').strip
    rows = read(STATS_SHEET, 'A:K')
    rows[1..].to_a.each_with_index do |row, i|
      next unless row[0]&.gsub('@', '')&.strip == acct
      current_health = (row[4].to_s.strip.empty? ? 50 : row[4].to_i)
      max_raw = row[10].to_s.strip
      return {
        row_num:        i + 2,
        id:             row[0].to_s.strip,
        name:           row[1].to_s.strip,
        current_health: current_health,
        endurance:      (row[5] || 10).to_i,
        magic:          (row[6] || 10).to_i,
        speed:          (row[7] || 0).to_i,
        skill:          (row[8] || 0).to_i,
        luck:           (row[9] || 5).to_i,
        health:         max_raw.empty? ? current_health : max_raw.to_i
      }
    end
    nil
  end

  def update_stat(acct, stat_name, new_val)
    acct = acct.to_s.gsub('@', '').strip
    col_map = {
      '건강'     => 'E', '현재건강' => 'E',
      '내구도'   => 'F', '인내'     => 'F',
      '마법능력' => 'G',
      '민첩'     => 'H', '속도'     => 'H',
      '기술'     => 'I',
      '행운'     => 'J',
      '최대건강' => 'K'
    }
    col = col_map[stat_name]
    return false unless col
    rows = read(STATS_SHEET, 'A:K')
    rows[1..].to_a.each_with_index do |row, i|
      next unless row[0]&.gsub('@', '')&.strip == acct
      write(STATS_SHEET, "#{col}#{i + 2}", [[new_val]])
      return true
    end
    false
  end
def log_house_score(house_name, gained, final_score)
    ws = read(LOG_SHEET, 'A:D')
    row_num = ws.length + 1
    now = Time.now.strftime('%Y-%m-%d %H:%M:%S')
    write(LOG_SHEET, "A#{row_num}:D#{row_num}", [[now, house_name, "기숙사 점수 +#{gained}", "최종 #{final_score}점"]])
  rescue => e
    puts "[log_house_score 오류] #{e.message}"
  end
end
