# commands/pouch_command.rb
# encoding: UTF-8

class PouchCommand
  MAX_CHARS = 450

  def initialize(sender, sheet_manager, mastodon_client, notification)
    @sender          = sender.to_s.gsub('@', '')
    @sheet_manager   = sheet_manager
    @mastodon_client = mastodon_client
    @notification    = notification
  end

  def execute
    status_id = @notification.dig('status', 'id')
    user = @sheet_manager.find_user(@sender)

    unless user
      @mastodon_client.post_status(
        "@#{@sender} 등록되지 않은 계정입니다.",
        reply_to_id: status_id, visibility: 'unlisted'
      )
      return
    end

    items = user[:items].split(',').map(&:strip).reject(&:empty?)

    lines = []
    lines << "@#{@sender}"
    lines << "──────────────────"
    lines << "#{user[:name]}의 소지품"
    lines << "──────────────────"
    lines << "크레딧: #{user[:credits]}C"
    lines << ""
    if items.any?
      lines << "[아이템]"
      items.each { |it| lines << "- #{it}" }
    else
      lines << "[아이템] 없음"
    end
    lines << "──────────────────"

    full_text = lines.join("\n")

    if full_text.length <= MAX_CHARS
      @mastodon_client.post_status(full_text, reply_to_id: status_id, visibility: 'unlisted')
    else
      chunks = split_into_chunks(lines, MAX_CHARS)
      reply_id = status_id
      chunks.each do |chunk|
        res = @mastodon_client.post_status(chunk, reply_to_id: reply_id, visibility: 'unlisted')
        begin
          reply_id = JSON.parse(res.body)['id'] if res
        rescue
        end
        sleep 1
      end
    end
  end

  private

  def split_into_chunks(lines, max_chars)
    chunks = []
    current = []
    lines.each do |line|
      if (current.join("\n") + "\n" + line).length > max_chars
        chunks << current.join("\n") unless current.empty?
        current = [line]
      else
        current << line
      end
    end
    chunks << current.join("\n") unless current.empty?
    chunks
  end
end
