# frozen_string_literal: true

class Webhooks::FacebookCommentJob < ApplicationJob
  queue_as :default

  # @param page_id [String] Facebook Page ID
  # @param value [Hash] The feed change value from the webhook payload
  def perform(page_id, value)
    Facebook::CommentService.new(page_id: page_id, value: value).perform
  end
end
