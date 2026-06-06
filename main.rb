#!/usr/bin/env ruby
# encoding: UTF-8

require 'mastodon'
require 'dotenv/load'
require 'google/apis/sheets_v4'
require 'googleauth'

require_relative 'mastodon_client'
require_relative 'sheet_manager'
require_relative 'command_parser'

# ============================================
# 환경 변수
# ============================================
LAST_FILE  = 'last_mention_id.txt'
BASE_URL   = ENV["MASTODON_BASE_URL"]
TOKEN      = ENV["MASTODON_TOKEN"]
SHEET_ID   = ENV["GOOGLE_SHEET_ID"]
CRED_PATH  = ENV["GOOGLE_APPLICATION_CREDENTIALS"]

if BASE_URL.nil? || TOKEN.nil? || SHEET_ID.nil? || CRED_PATH.nil?
  puts "[ERROR] 환경 변수가 빠졌습니다. (MASTODON_BASE_URL / MASTODON_TOKEN / GOOGLE_SHEET_ID / GOOGLE_APPLICATION_CREDENTIALS)"
  exit 1
end

# ============================================
# Mastodon 클라이언트
# ============================================
client = MastodonClient.new(base_url: BASE_URL, token: TOKEN)

# ============================================
# Google Sheets 클라이언트
# ============================================
Sheets = Google::Apis::SheetsV4
service = Sheets::SheetsService.new
service.client_options.application_name = "FortunaeFons ShopBot"

service.authorization = Google::Auth::ServiceAccountCredentials.make_creds(
  json_key_io: File.open(CRED_PATH),
  scope: ['https://www.googleapis.com/auth/spreadsheets']
)

sheet_manager = SheetManager.new(service, SHEET_ID)

# ============================================
# last_id 읽기
# ============================================
last_id =
  if File.exist?(LAST_FILE)
    File.read(LAST_FILE).to_i
  else
    0
  end

puts "----------------------------------------"
puts "상점봇 Polling 시작 (최종 처리 ID: #{last_id})"
puts "----------------------------------------"

# ============================================
# 메인 루프
# ============================================
loop do
  begin
    notifications = client.notifications(limit: 40)
    notifications.reverse_each do |n|
      nid = n["id"].to_i
      next unless nid > last_id

      notification_type = n["type"]
      next unless notification_type == "mention"

      acct = n["account"]["acct"]
      content = n.dig("status", "content") || ""

      puts "[NEW MENTION] ID=#{nid}, from=@#{acct}"

      # 처리 전 last_id 저장 (중복 응답 방지)
      last_id = nid
      File.write(LAST_FILE, last_id.to_s)

      # CommandParser로 명령 처리
      CommandParser.parse(client, sheet_manager, n)

      sleep 2
    end

  rescue => e
    puts "[ERROR] #{e.class} - #{e.message}"
    puts e.backtrace.first(5).join("\n  ↳ ")
  end

  sleep 7
end
