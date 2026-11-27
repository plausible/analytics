defmodule Plausible.Billing.PaddleBilling.WebhookFailure do
  @moduledoc """
  Schema representing a Paddle Billing webhook that passed signature
  verification but could not be processed.

  The event is not stored with the subscription events, since processing
  rolled back. This table keeps the payload for inspection.
  """

  use Ecto.Schema

  schema "billing_webhook_failures" do
    field :billing_event_id, :string
    field :event_type, :string
    field :payload, :map
    field :error, :string

    timestamps(updated_at: false)
  end
end
