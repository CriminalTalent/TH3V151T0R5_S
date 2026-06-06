# encoding: UTF-8
class PouchCommand
  MAX_LENGTH = 500

  def initialize(student_id, sheet_manager, mastodon_client = nil, notification = nil)
    @student_id = student_id.gsub('@', '')
    @sheet_manager = sheet_manager
    @mastodon_client = mastodon_client
    @notification = notification
  end

  def execute
    player = @sheet_manager.find_user(@student_id)
    unless player
      message = "@#{@student_id} 아직 학적부에 없어요~"
      send_reply(message) if @mastodon_client
      return message
    end

    galleons = player[:galleons].to_i
    items_raw = player[:items].to_s.strip

    if items_raw.empty?
      items_display = "없음"
    else
      items_array = items_raw.split(",").map(&:strip)
      item_counts = Hash.new(0)
      items_array.each { |item| item_counts[item] += 1 }

      items_display = item_counts.map do |item, count|
        count > 1 ? "#{item} x#{count}" : item
      end.join(", ")
    end

    # 전체 메시지 생성
    full_message = "@#{@student_id}\n갈레온: #{galleons}개\n아이템: #{items_display}"

    # 500자 이하면 한 번에 전송
    if full_message.length <= MAX_LENGTH
      send_reply(full_message) if @mastodon_client
      return full_message
    end

    # 500자 초과면 스레드로 분할 전송
    send_as_thread(galleons, items_display) if @mastodon_client
    return full_message
  end

  private

  def send_reply(message, reply_to_id = nil)
    return unless @mastodon_client && @notification

    status_id = reply_to_id || @notification.dig("status", "id")
    return unless status_id

    begin
      @mastodon_client.post_status(message, reply_to_id: status_id, visibility: "unlisted")
    rescue => e
      puts "[POUCH] 답글 전송 실패: #{e.class} - #{e.message}"
    end
  end

  def send_as_thread(galleons, items_display)
    # 첫 번째 메시지: 멘션 + 갈레온
    first_message = "@#{@student_id}\n갈레온: #{galleons}개"
    
    response = send_reply(first_message)
    return unless response
    
    # 응답에서 status_id 추출
    thread_id = 
      if response.is_a?(Net::HTTPSuccess)
        begin
          JSON.parse(response.body)["id"]
        rescue
          @notification.dig("status", "id")
        end
      else
        @notification.dig("status", "id")
      end

    sleep 1

    # 아이템 목록을 500자 단위로 분할
    prefix = "아이템: "
    remaining = items_display
    
    while remaining.length > 0
      # 현재 청크 크기 계산 (prefix 포함)
      available_length = MAX_LENGTH - prefix.length - 10 # 여유분
      
      if remaining.length <= available_length
        # 마지막 청크
        chunk_message = "#{prefix}#{remaining}"
        send_reply(chunk_message, thread_id)
        break
      else
        # 쉼표 기준으로 자르기
        cut_pos = remaining.rindex(", ", available_length)
        
        if cut_pos.nil? || cut_pos < available_length / 2
          # 적절한 쉼표를 못 찾으면 강제로 자르기
          cut_pos = available_length
        else
          cut_pos += 2 # ", " 포함
        end
        
        chunk = remaining[0...cut_pos].strip
        chunk_message = "#{prefix}#{chunk}"
        
        send_reply(chunk_message, thread_id)
        
        remaining = remaining[cut_pos..-1].strip
        remaining = remaining.sub(/^,\s*/, '') # 앞 쉼표 제거
        prefix = "" # 두 번째부터는 prefix 없이
        
        sleep 1
      end
    end
  end
end
