# toot_scheduler.rb
# encoding: UTF-8
# 매일 자정: 등록된 유저의 마스토돈 툿 수를 가져와 100툿당 15크레딧 정산

require 'rufus-scheduler'
require 'dotenv/load'
require 'google/apis/sheets_v4'
require 'googleauth'
require 'net/http'
require 'json'
require 'uri'

require_relative 'mastodon_client'
require_relative 'sheet_manager'

BASE_URL  = ENV['MASTODON_BASE_URL']
TOKEN     = ENV['MASTODON_TOKEN']
SHEET_ID  = ENV['GOOGLE_SHEET_ID']
CRED_PATH = ENV['GOOGLE_APPLICATION_CREDENTIALS'] || ENV['GOOGLE_CREDENTIALS_PATH']

# ──────────────────────────────────────────────
# 마스토돈 계정의 공개 툿 수 조회
# GET /api/v1/accounts/lookup?acct=username → statuses_count
# ──────────────────────────────────────────────
def fetch_toot_count(base_url, token, acct_id)
  # acct_id는 "user" 또는 "user@domain" 형태
  local_user = acct_id.split('@').first
  uri = URI("#{base_url}/api/v1/accounts/lookup")
  uri.query = URI.encode_www_form(acct: local_user)

  req = Net::HTTP::Get.new(uri)
  req['Authorization'] = "Bearer #{token}"

  res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.request(req)
  end

  return nil unless res.code.to_i == 200
  data = JSON.parse(res.body)
  data['statuses_count'].to_i
rescue => e
  puts "[툿조회 오류] @#{acct_id}: #{e.message}"
  nil
end

# ──────────────────────────────────────────────
# 정산 실행
# ──────────────────────────────────────────────
def run_toot_settlement(sheet_manager, base_url, token)
  puts "[툿정산] 시작 #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"

  users = sheet_manager.all_users
  settled_count = 0

  users.each do |user|
    acct = user[:id].gsub('@', '')
    next if acct.empty?

    current_count = fetch_toot_count(base_url, token, acct)
    if current_count.nil?
      puts "[툿정산] @#{acct} 툿 수 조회 실패, 스킵"
      next
    end

    # toot_count 갱신 (기록용)
    sheet_manager.update_toot_count(acct, current_count)

    # 크레딧 정산
    result = sheet_manager.settle_toot_credits(acct, current_count)
    if result && result[:earned] > 0
      settled_count += 1
      puts "[툿정산] @#{acct} +#{result[:earned]}C (#{result[:units]}단위)"
    end

    sleep 0.3  # API 과부하 방지
  end

  puts "[툿정산] 완료. 정산된 유저: #{settled_count}명"
rescue => e
  puts "[툿정산 오류] #{e.class}: #{e.message}"
  puts e.backtrace.first(3)
end

# ──────────────────────────────────────────────
# Google Sheets 초기화
# ──────────────────────────────────────────────
service = Google::Apis::SheetsV4::SheetsService.new
service.client_options.application_name = 'ShopBot'
service.authorization = Google::Auth::ServiceAccountCredentials.make_creds(
  json_key_io: File.open(CRED_PATH),
  scope: ['https://www.googleapis.com/auth/spreadsheets']
)
sheet_manager = SheetManager.new(service, SHEET_ID)

# ──────────────────────────────────────────────
# 스케줄러
# ──────────────────────────────────────────────
scheduler = Rufus::Scheduler.new

# 매일 자정 00:00 (KST 기준, TZ=Asia/Seoul 설정 필요)
scheduler.cron '0 0 * * *', timezone: 'Asia/Seoul' do
  run_toot_settlement(sheet_manager, BASE_URL, TOKEN)
end

puts "[툿정산 스케줄러] 시작. 매일 자정(KST) 정산 실행."
scheduler.join
