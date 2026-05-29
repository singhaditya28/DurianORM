# frozen_string_literal: true

# Replies to an Instagram comment using the Graph API.
# Called instead of the DM send service when the conversation type is 'instagram_comment'.
class Instagram::CommentReplyService
  pattr_initialize [:message!]

  def perform
    # Mirror Base::SendOnChannelService guards
    return unless message.outgoing? || message.template?
    return if message.private?
    return if message.source_id.present? # already sent / echo loop

    return unless message.content.present?

    comment_id = last_incoming_comment_id
    return Rails.logger.warn("Instagram::CommentReplyService: no comment_id for conversation #{conversation.id}") unless comment_id

    # Channel::Instagram (IG Login) uses graph.instagram.com; Channel::FacebookPage uses graph.facebook.com
    host = channel.is_a?(Channel::FacebookPage) ? 'graph.facebook.com' : 'graph.instagram.com'
    response = HTTParty.post(
      "https://#{host}/v22.0/#{comment_id}/replies",
      body: { message: message.content, access_token: instagram_access_token }
    )

    parsed = response.parsed_response
    if response.success? && parsed['id'].present?
      message.update!(source_id: parsed['id'])
    else
      err = "#{parsed.dig('error', 'code')} - #{parsed.dig('error', 'message')}"
      Rails.logger.error("Instagram::CommentReplyService error: #{err}")
      Messages::StatusUpdateService.new(message, 'failed', err).perform
    end
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: message.account).capture_exception
  end

  private

  def conversation
    message.conversation
  end

  def inbox
    conversation.inbox
  end

  def channel
    inbox.channel
  end

  # Works for both Channel::Instagram (access_token) and Channel::FacebookPage (page_access_token).
  def instagram_access_token
    channel.is_a?(Channel::FacebookPage) ? channel.page_access_token : channel.access_token
  end

  # The most recent incoming comment message holds the comment_id we're replying to.
  # Filter to messages that have a source_id to avoid picking up DM messages.
  def last_incoming_comment_id
    conversation.messages.incoming.where.not(source_id: nil).order(:created_at).last&.source_id
  end
end
