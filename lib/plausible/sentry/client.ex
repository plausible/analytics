defmodule Plausible.Sentry.Client do
  @behaviour Sentry.HTTPClient

  defguardp is_redirect(status) when is_integer(status) and status >= 300 and status < 400

  require Logger

  def post(url, headers, body) do
    req_opts = Application.get_env(:plausible, __MODULE__)[:finch_request_opts] || []

    :post
    |> Finch.build(url, headers, body)
    |> Finch.request(Plausible.Finch, req_opts)
    |> handle_response()
  end

  defp handle_response(resp) do
    case resp do
      {:ok, %{status: status, headers: _}} when is_redirect(status) ->
        # Just playing safe here. hackney client didn't support those; redirects are opt-in in hackney
        Logger.warning("Sentry returned a redirect that is not handled yet.")
        {:error, :stop}

      {:ok, %{status: status, body: body, headers: headers}} ->
        {:ok, status, headers, body}

      {:error, error} = e ->
        Logger.warning("Sentry call failed with: #{inspect(error)}")
        e
    end
  end
end
