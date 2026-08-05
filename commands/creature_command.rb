# commands/creature_command.rb
# encoding: UTF-8
class CreatureCommand
  DEXENTRY_STATE = {}
  DEXENTRY_TTL = 3600
  
  def initialize(content, student_id, sheet_manager, mastodon_client, notification)
    @content         = content
    @student_id      = student_id.gsub('@', '')
    @sheet_manager   = sheet_manager
    @mastodon_client = mastodon_client
    @notification    = notification
    @status          = notification['status']
  end
  
  def execute
    status_id = @status['id']
    in_reply_to_id = @status['in_reply_to_id']
    
    user = @sheet_manager.find_user(@student_id)
    return safe_reply("@#{@student_id} 등록되지 않은 계정입니다.") unless user
    
    creatures_db = @sheet_manager.get_creatures
    return safe_reply("@#{@student_id} 도감 데이터를 불러올 수 없습니다.") if creatures_db.empty?
    
    user_creatures_map = @sheet_manager.get_user_creatures_with_count(@student_id)
    discovered = creatures_db.select { |c| user_creatures_map.key?(c[:name]) }
    return safe_reply("@#{@student_id} 아직 발견한 생물이 없습니다.") if discovered.empty?
    
    current_page = get_current_page(in_reply_to_id, status_id)
    current_page = [current_page, discovered.length - 1].min
    current_page = [current_page, 0].max
    
    creature = discovered[current_page]
    count = user_creatures_map[creature[:name]] || 0
    display_creature(creature, count, current_page, discovered.length, status_id)
    
    DEXENTRY_STATE[status_id] = { page: current_page, timestamp: Time.now.to_i }
    cleanup_old_states
  end
  
  private
  
  def get_current_page(in_reply_to_id, status_id)
    if in_reply_to_id && DEXENTRY_STATE[in_reply_to_id]
      base_page = DEXENTRY_STATE[in_reply_to_id][:page]
      
      case @content.strip
      when /\[도감\/다음\]/
        base_page + 1
      when /\[도감\/이전\]/
        base_page - 1
      else
        base_page
      end
    else
      0
    end
  end
  
  def display_creature(creature, count, page, total, status_id)
    lines = []
    lines << "[ #{creature[:name]} ]"
    lines << "──────────────────"
    lines << creature[:description] unless creature[:description].empty?
    lines << ""
    lines << "위치: #{creature[:location]}" unless creature[:location].empty?
    
    unless creature[:rarity].empty?
      rarity_num = creature[:rarity].to_i
      rarity_bar = rarity_num > 0 ? ('★' * rarity_num) + ('☆' * (10 - rarity_num)) : '☆☆☆☆☆☆☆☆☆☆'
      lines << "레어도: #{rarity_bar} (#{rarity_num}/10)"
    end
    
    lines << "발견: #{count}개" if count > 0
    lines << ""
    lines << "(#{page + 1}/#{total})"
    
    if total > 1
      nav = []
      nav << "[도감/이전]" if page > 0
      nav << "[도감/다음]" if page < total - 1
      lines << nav.join(" / ") if nav.any?
    end
    
    text = lines.join("\n")
    safe_reply("@#{@student_id} #{text}")
  end
  
  def cleanup_old_states
    now = Time.now.to_i
    DEXENTRY_STATE.delete_if { |_, v| now - v[:timestamp] > DEXENTRY_TTL }
  end
  
  def safe_reply(text)
    return if text.nil? || text.to_s.strip.empty?
    @mastodon_client.post_status(
      text,
      reply_to_id: @status['id'],
      visibility: 'unlisted'
    )
  rescue => e
    puts "[도감 응답] #{e.message}"
  end
end
