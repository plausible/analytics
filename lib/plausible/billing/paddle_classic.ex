defmodule Plausible.Billing.PaddleClassic do
  @moduledoc """
  Entry point to the Paddle Classic integration: the HTTP client, webhook
  handling and the mix tasks that talk to Classic all live under this namespace.

  To be deleted after the Paddle Billing migration.
  """

  @doc """
  Returns the configured Paddle Classic API client module. Swapped for
  mocks in dev, test and e2e environments.
  """
  def api(), do: Application.fetch_env!(:plausible, :paddle_classic_api)
end
