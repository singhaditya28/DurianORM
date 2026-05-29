# frozen_string_literal: true

# Replies to a Facebook Page comment using the Graph API.
# Called instead of the DM send service when conversation type is 'facebook_comment'.
class Facebook::CommentReplyService
  pattr_initialize [:message!]

  def perform
    # Mirror Base::SendOnChannelService guards
    return unless message.outgoing? || message.template?
    return if message.private?
    return if message.source_id.present? # already sent / echo loop

    return unless message.content.present?

    comment_id = last_incoming_comment_id
    return Rails.logger.warn("Facebook::CommentReplyService: no comment_id for conversation #{conversation.id}") unless comment_id

    response = HTTParty.post(
      "https://graph.facebook.com/v19.0/#{comment_id}/comments",
      body: { message: message.content, access_token: channel.page_access_token }
    )

    parsed = response.parsed_response
    if response.success? && parsed['id'].present?
      message.update!(source_id: parsed['id'])
    else
      err = "#{parsed.dig('error', 'code')} - #{parsed.dig('error', 'message')}"
      Rails.logger.error("Facebook::CommentReplyService error: #{err}")
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

  def last_incoming_comment_id
    conversation.messages.incoming.order(:created_at).last&.source_id
  end
end
