# frozen_string_literal: true

# Rack middleware that intercepts POST /bot requests and extracts
# Facebook Page feed comment events before the facebook-messenger gem
# processes the payload (the gem only handles messaging/DM events).
class FacebookCommentsMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    if post_to_bot?(env)
      body = env['rack.input'].read
      env['rack.input'] = StringIO.new(body) # rewind for downstream gem

      begin
        payload = JSON.parse(body)
        process_feed_comments(payload) if page_comment_event?(payload)
      rescue JSON::ParseError, StandardError => e
        Rails.logger.error("FacebookCommentsMiddleware error: #{e.message}")
      end
    end

    @app.call(env)
  end

  private

  def post_to_bot?(env)
    env['REQUEST_METHOD'] == 'POST' && env['PATH_INFO']&.start_with?('/bot')
  end

  def page_comment_event?(payload)
    return false unless payload['object'] == 'page'

    payload['entry']&.any? do |entry|
      entry['changes']&.any? do |change|
        change['field'] == 'feed' &&
          change.dig('value', 'item') == 'comment' &&
          change.dig('value', 'verb') == 'add'
      end
    end
  end

  def process_feed_comments(payload)
    payload['entry'].each do |entry|
      page_id = entry['id']
      next if page_id.blank?

      entry['changes']&.each do |change|
        next unless change['field'] == 'feed'

        value = change['value'] || {}
        next unless value['item'] == 'comment' && value['verb'] == 'add'

        Rails.logger.info("FacebookCommentsMiddleware: comment on page #{page_id}")
        Webhooks::FacebookCommentJob.perform_later(page_id, value)
      end
    end
  end
end
