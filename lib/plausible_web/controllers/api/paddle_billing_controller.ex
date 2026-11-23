defmodule PlausibleWeb.Api.PaddleBillingController do
  @moduledoc """
  Receives Paddle Billing webhooks.

  Paddle retries every non-2xx response, so events we don't handle are
  acknowledged and ignored.
  """

  use PlausibleWeb, :controller

  require Logger

  alias Plausible.Billing.PaddleBilling.{WebhookSignature, Webhooks}

  plug WebhookSignature

  def webhook(conn, %{"event_type" => "subscription.created"}) do
    conn.body_params
    |> Webhooks.subscription_created()
    |> webhook_response(conn)
  end

  def webhook(conn, %{"event_type" => "subscription.updated"}) do
    conn.body_params
    |> Webhooks.subscription_updated()
    |> webhook_response(conn)
  end

  def webhook(conn, _params) do
    send_resp(conn, 200, "")
  end

  defp webhook_response({:ok, _}, conn), do: send_resp(conn, 200, "")

  defp webhook_response({:error, details}, conn) do
    Logger.error("Error processing Paddle Billing webhook: #{inspect(details)}")

    conn |> send_resp(400, "") |> halt()
  end
end
