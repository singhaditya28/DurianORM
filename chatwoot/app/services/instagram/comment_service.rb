# frozen_string_literal: true

# Processes an incoming Instagram comment and creates a Chatwoot
# conversation/message for it.
#
# Instagram comment change value shape:
# {
#   "id"    => "COMMENT_ID",
#   "text"  => "Comment text",
#   "from"  => { "id" => "USER_ID", "username" => "username" },
#   "media" => { "id" => "MEDIA_ID", "media_product_type" => "FEED" }
# }
class Instagram::CommentService
  def initialize(ig_account_id:, value:)
    @ig_account_id = ig_account_id
    @value         = value.with_indifferent_access
  end

  def perform
    return unless channel && inbox
    # Skip comments made by the account itself (our own replies echoed back)
    return if sender_id.to_s == @ig_account_id.to_s

    ActiveRecord::Base.transaction do
      build_contact_inbox
      build_message
    end
    apply_comment_label
  rescue StandardError => e
    ChatwootExceptionTracker.new(e).capture_exception
  end

  private

  def channel
    @channel ||= Channel::Instagram.find_by(instagram_id: @ig_account_id) ||
                 Channel::FacebookPage.find_by(instagram_id: @ig_account_id)
  end

  def inbox
    @inbox ||= channel&.inbox
  end

  def sender_id
    @value.dig('from', 'id')
  end

  def sender_username
    @value.dig('from', 'username') || sender_id
  end

  def comment_id
    @value['id']
  end

  def comment_text
    @value['text']
  end

  def media_id
    @value.dig('media', 'id')
  end

  def build_contact_inbox
    @contact_inbox = if channel.is_a?(Channel::Instagram)
                       channel.create_contact_inbox(sender_id, sender_username)
                     else
                       # Fallback: use ContactInboxWithContactBuilder for FacebookPage channel
                       ::ContactInboxWithContactBuilder.new(
                         source_id: sender_id,
                         inbox: inbox,
                         contact_attributes: {
                           name: sender_username,
                           account_id: inbox.account_id
                         }
                       ).perform
                     end
  end

  def build_message
    @message = conversation.messages.find_or_create_by!(source_id: comment_id) do |m|
      m.account_id   = conversation.account_id
      m.inbox_id     = conversation.inbox_id
      m.message_type = :incoming
      m.content      = comment_text
      m.sender       = @contact_inbox.contact
      m.content_attributes = { item_type: 'instagram_comment', media_id: media_id }
    end
  end

  def conversation
    @conversation ||= find_or_create_conversation
  end

  def find_or_create_conversation
    # Group all comments on the same media into one conversation.
    # Scope to instagram_comment type only — never find/modify a DM conversation.
    existing = Conversation.where(
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      contact_id: @contact_inbox.contact_id
    ).where("additional_attributes->>'type' = 'instagram_comment'")
                           .where("additional_attributes->>'media_id' = ?", media_id).first

    existing || Conversation.create!(
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      contact_id: @contact_inbox.contact_id,
      contact_inbox_id: @contact_inbox.id,
      additional_attributes: { media_id: media_id, type: 'instagram_comment' }
    )
  end

  def apply_comment_label
    return unless @conversation

    # Safety: never apply comment label to a DM conversation.
    conv_type = @conversation.additional_attributes&.dig('type').to_s
    return if conv_type.present? && !conv_type.include?('comment')

    ensure_label_exists('comment', '#e84393') # pink — distinct from DM conversations
    @conversation.add_labels(['comment'])
  rescue StandardError => e
    Rails.logger.warn("Could not apply comment label: #{e.message}")
  end

  def ensure_label_exists(title, color)
    Label.find_or_create_by!(account_id: inbox.account_id, title: title) do |l|
      l.color           = color
      l.description     = 'Post comment (auto-tagged)'
      l.show_on_sidebar = true
    end
  end
end
