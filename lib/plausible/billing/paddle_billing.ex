defmodule Plausible.Billing.PaddleBilling do
  @moduledoc """
  Entry point to the Paddle Billing integration: the HTTP client, webhook
  handling and the mix tasks that talk to Billing API all live under this namespace.
  """

  @doc """
  Returns the configured Paddle Billing API client module. Swapped for
  mocks in dev, test and e2e environments.
  """
  def api(), do: Application.fetch_env!(:plausible, :paddle_billing_api)

  @doc """
  Returns the secret key of the notification destination, used to verify
  webhook signatures.
  """
  def webhook_secret(), do: Application.get_env(:plausible, :paddle_billing)[:webhook_secret]
end
