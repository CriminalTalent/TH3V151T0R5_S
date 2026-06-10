# commands/yn_command.rb
# encoding: UTF-8

class YnCommand
  ANSWERS = ['YES', 'NO', 'Maybe', 'Why not?'].freeze

  def self.run(mastodon_client, notification)
    sender    = notification.dig('account', 'acct') || ''
    status_id = notification.dig('status', 'id')

    mastodon_client.post_status(
      "@#{sender} #{ANSWERS.sample}",
      reply_to_id: status_id, visibility: 'unlisted'
    )
  rescue => e
    puts "[YN 오류] #{e.message}"
  end
end
