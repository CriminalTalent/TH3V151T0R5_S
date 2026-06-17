# commands/coin_command.rb
# encoding: UTF-8

class CoinCommand
  def self.run(mastodon_client, notification)
    sender    = notification.dig('account', 'acct') || ''
    status_id = notification.dig('status', 'id')
    result    = ['앞면', '뒷면'].sample

    mastodon_client.post_status(
      "@#{sender} #{result}",
      reply_to_id: status_id, visibility: 'unlisted'
    )
  rescue => e
    puts "[COIN 오류] #{e.message}"
  end
end
