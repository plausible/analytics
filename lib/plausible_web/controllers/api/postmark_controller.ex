defmodule PlausibleWeb.Api.PostmarkController do
  @moduledoc """
  Receives Postmark's Bounce and SpamComplaint webhooks and records
  addresses in `Plausible.EmailSuppressions`.

  See https://postmarkapp.com/developer/webhooks/webhooks-overview
  """

  use PlausibleWeb, :controller

  plug :verify_basic_auth

  # https://postmarkapp.com/developer/api/bounce-api#bounce-types
  @suppressing_bounce_reasons %{
    "HardBounce" => :hard_bounce,
    "BadEmailAddress" => :bad_email_address,
    "Blocked" => :blocked,
    # SpamNotification is an automated rejection at delivery time
    # Postmark classifies it as a Bounce (not a SpamComplaint), 
    # confirmed with Postmark support
    "SpamNotification" => :spam_notification
  }

  def webhook(conn, %{"RecordType" => "Bounce"} = params) do
    case Map.fetch(@suppressing_bounce_reasons, params["Type"]) do
      {:ok, reason} ->
        params
        |> suppression_attrs()
        |> Map.put(:reason, reason)
        |> Plausible.EmailSuppressions.create_from_bounce()
        |> log_on_error(params)

      :error ->
        :ignored
    end

    ok(conn)
  end

  def webhook(conn, %{"RecordType" => "SpamComplaint"} = params) do
    params
    |> suppression_attrs()
    |> Plausible.EmailSuppressions.create_from_spam_complaint()
    |> log_on_error(params)

    ok(conn)
  end

  def webhook(conn, params) do
    Sentry.capture_message("Received unexpected Postmark webhook record type",
      extra: %{record_type: params["RecordType"], params: params}
    )

    ok(conn)
  end

  defp suppression_attrs(params) do
    %{
      email: params["Email"],
      source: :webhook,
      postmark_bounce_id: params["ID"],
      postmark_inactive: params["Inactive"] || false,
      can_activate: params["CanActivate"] || false,
      details: params["Details"]
    }
  end

  defp log_on_error({:ok, _suppression}, _params), do: :ok

  defp log_on_error({:error, changeset}, params) do
    Sentry.capture_message("Failed to record Postmark suppression",
      extra: %{
        email: params["Email"],
        record_type: params["RecordType"],
        errors: inspect(changeset.errors)
      }
    )
  end

  defp ok(conn), do: json(conn, %{})

  defp verify_basic_auth(conn, _opts) do
    config = Application.get_env(:plausible, Plausible.Postmark, [])

    username =
      Keyword.get(config, :webhook_username) ||
        raise "POSTMARK_WEBHOOK_USERNAME is not configured"

    password =
      Keyword.get(config, :webhook_password) ||
        raise "POSTMARK_WEBHOOK_PASSWORD is not configured"

    Plug.BasicAuth.basic_auth(conn, username: username, password: password)
  end
end
