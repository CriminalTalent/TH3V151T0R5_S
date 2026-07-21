#!/usr/bin/env ruby
# encoding: UTF-8

require 'dotenv/load'
require 'google/apis/sheets_v4'
require 'googleauth'

require_relative 'mastodon_client'
require_relative 'sheet_manager'
require_relative 'command_parser'

LAST_FILE = 'last_mention_id.txt'.freeze

BASE_URL  = ENV['MASTODON_BASE_URL']
TOKEN     = ENV['MASTODON_TOKEN']
SHEET_ID  = ENV['GOOGLE_SHEET_ID']
CRED_PATH =
  ENV['GOOGLE_APPLICATION_CREDENTIALS'] ||
  ENV['GOOGLE_CREDENTIALS_PATH']

required_env = {
  'MASTODON_BASE_URL' => BASE_URL,
  'MASTODON_TOKEN' => TOKEN,
  'GOOGLE_SHEET_ID' => SHEET_ID,
  'GOOGLE_APPLICATION_CREDENTIALS' => CRED_PATH
}

missing_env = required_env.select do |_key, value|
  value.nil? || value.to_s.strip.empty?
end.keys

unless missing_env.empty?
  puts(
    "[ERROR] 환경변수 누락: " \
    "#{missing_env.join(', ')}"
  )
  exit 1
end

unless File.file?(CRED_PATH)
  puts "[ERROR] Google 인증 파일을 찾을 수 없습니다: #{CRED_PATH}"
  exit 1
end

def read_last_id
  return '0' unless File.exist?(LAST_FILE)

  value = File.read(LAST_FILE).to_s.strip
  value.match?(/\A\d+\z/) ? value : '0'
rescue => e
  puts "[LAST ID 읽기 오류] #{e.class}: #{e.message}"
  '0'
end

def write_last_id(id)
  value = id.to_s.strip
  return false unless value.match?(/\A\d+\z/)

  temp_path = "#{LAST_FILE}.tmp"

  File.write(temp_path, value)
  File.rename(temp_path, LAST_FILE)

  true
rescue => e
  puts "[LAST ID 저장 오류] #{e.class}: #{e.message}"

  begin
    File.delete(temp_path) if defined?(temp_path) && File.exist?(temp_path)
  rescue
    nil
  end

  false
end

def newer_id?(candidate, current)
  candidate.to_i > current.to_i
end

service = Google::Apis::SheetsV4::SheetsService.new
service.client_options.application_name = 'ShopBot'

credentials_file = File.open(CRED_PATH)

service.authorization =
  Google::Auth::ServiceAccountCredentials.make_creds(
    json_key_io: credentials_file,
    scope: [
      'https://www.googleapis.com/auth/spreadsheets'
    ]
  )

credentials_file.close

sheet_manager = SheetManager.new(
  service,
  SHEET_ID
)

client = MastodonClient.new(
  base_url: BASE_URL,
  token: TOKEN
)

last_id = read_last_id

# 최초 실행 시 기존 멘션을 무시하고
# 현재 가장 최신 멘션부터 감시를 시작한다.
if last_id == '0'
  begin
    latest_mentions = client.notifications(
      limit: 1,
      types: ['mention']
    )

    if latest_mentions.any?
      latest_id = latest_mentions.first['id'].to_s

      if latest_id.match?(/\A\d+\z/)
        last_id = latest_id
        write_last_id(last_id)
      end
    end
  rescue => e
    puts "[초기화 오류] #{e.class}: #{e.message}"
  end
end

puts '──────────────────────────────────'
puts "상점봇 시작 (last_id: #{last_id})"
puts '──────────────────────────────────'

loop do
  begin
    notifications = client.notifications(
      limit: 40,
      since_id: last_id == '0' ? nil : last_id,
      types: ['mention']
    )

    notifications
      .select { |notification| notification['type'] == 'mention' }
      .sort_by { |notification| notification['id'].to_i }
      .each do |notification|
        notification_id = notification['id'].to_s

        next unless notification_id.match?(/\A\d+\z/)
        next unless newer_id?(notification_id, last_id)

        sender_acct =
          notification.dig('account', 'acct').to_s.strip

        status_id =
          notification.dig('status', 'id').to_s.strip

        puts(
          "[멘션] notification_id=#{notification_id}, " \
          "status_id=#{status_id}, " \
          "from=@#{sender_acct}"
        )

        begin
          CommandParser.parse(
            client,
            sheet_manager,
            notification
          )
        rescue => e
          puts(
            "[명령 처리 오류] " \
            "notification_id=#{notification_id} " \
            "#{e.class}: #{e.message}"
          )

          puts e.backtrace.first(5).join("\n  ")
        ensure
          last_id = notification_id
          write_last_id(last_id)
        end

        sleep 2
      end
  rescue => e
    puts "[루프 오류] #{e.class}: #{e.message}"
    puts e.backtrace.first(5).join("\n  ")
  end

  sleep 7
end
