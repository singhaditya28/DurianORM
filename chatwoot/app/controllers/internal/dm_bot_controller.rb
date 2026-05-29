# frozen_string_literal: true

# Receives AgentBot webhook payloads fired by AgentBotListener and dispatches
# them to Integrations::DmBot::ProcessorService.
#
# The AgentBot record's outgoing_url must be set to:
#   http://localhost:3000/internal/dm_bot/webhook
#
class Internal::DmBotController < ApplicationController
  def webhook
    payload = JSON.parse(request.body.read, symbolize_names: true)
    event   = payload[:event]
    message = find_message(payload)

    if message
      Integrations::DmBot::ProcessorService.new(
        event_name: event,
        hook: agent_bot,
        event_data: { message: message }
      ).perform
    end

    head :ok
  rescue StandardError => e
    Rails.logger.error("DmBot webhook error: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
    head :ok # Always 200 so Chatwoot doesn't retry
  end

  private

  def find_message(payload)
    message_id = payload.dig(:id) || payload.dig(:message, :id)
    Message.find_by(id: message_id)
  end

  def agent_bot
    # The bot is identified by the secret token in the X-Chatwoot-Signature header,
    # but for an internal call we just find the single DM Bot record.
    @agent_bot ||= AgentBot.find_by(name: 'DM Bot')
  end
end
