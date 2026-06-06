# streaming_client.rb
require 'net/http'
require 'uri'
require 'json'

class MastodonStreamingClient
  def initialize(base_url:, token:)
    @base_url = base_url.sub(%r{/\z}, '')
    @token    = token
  end

  # ===========================
  # 🔥 알림 스트림 (notification 전용)
  #   - 각 notification JSON 을 블록으로 넘겨줌
  # ===========================
  def stream_notifications
    uri  = URI("#{@base_url}/api/v1/streaming/user/notification")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')

    req = Net::HTTP::Get.new(uri)
    req['Authorization'] = "Bearer #{@token}"

    puts "[STREAM] 연결 시도: #{uri}"

    http.request(req) do |res|
      unless res.is_a?(Net::HTTPSuccess)
        puts "[STREAM] HTTP #{res.code} #{res.message}"
        puts "[STREAM] body: #{res.body}"
        return
      end

      buffer     = +""
      event_type = nil

      res.read_body do |chunk|
        buffer << chunk

        # 줄 단위로 쪼개기
        while (line = buffer.slice!(/.+\n/))
          line = line.strip

          if line.empty?
            # 이벤트 하나 끝
            event_type = nil
          elsif line.start_with?("event:")
            event_type = line.split(":", 2)[1].strip
          elsif line.start_with?("data:")
            data = line.split(":", 2)[1].strip

            if event_type == "notification"
              begin
                notif = JSON.parse(data)
                yield notif if block_given?
              rescue => e
                puts "[STREAM] JSON 파싱 오류: #{e.class} - #{e.message}"
              end
            end
          end
        end
      end
    end
  rescue => e
    puts "[STREAM] 연결 오류: #{e.class} - #{e.message}"
  end
end
