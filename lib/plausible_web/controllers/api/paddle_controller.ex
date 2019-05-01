defmodule PlausibleWeb.Api.PaddleController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  require Logger

  def webhook(conn, %{"alert_name" => "subscription_created"} = params) do
    Plausible.Billing.subscription_created(params)
    |> webhook_response(conn, params)
  end

  def webhook(conn, %{"alert_name" => "subscription_updated"} = params) do
    Plausible.Billing.subscription_updated(params)
    |> webhook_response(conn, params)
  end

  defp webhook_response(conn, {:ok, _}, _params) do
    json(conn, "")
  end

  defp webhook_response(conn, {:error, changeset}, params) do
    request = Sentry.Plug.build_request_interface_data(conn, [])
    Sentry.capture_message("Error processing Paddle webhook", extra: %{errors: inspect(changeset.errors), params: params, request: request})
    Logger.error("Error processing Paddle webhook: #{inspect(changeset)}")

    conn |> send_resp(400, "")
  end
end
