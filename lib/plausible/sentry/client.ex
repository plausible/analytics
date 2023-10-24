defmodule Plausible.Sentry.Client do
  @behaviour Sentry.HTTPClient

  defguardp is_redirect(status) when is_integer(status) and status >= 300 and status < 400

  require Logger

  @doc """
  The Sentry.HTTPClient behaviour requires a child spec to be supplied.
  In this case we don't want Sentry to manage our Finch instances, hence it's fed
  with a dummy module for the sake of the contract.

  XXX: Submit a Sentry PR making the child spec callback optional.
  """
  def child_spec do
    Task.child_spec(fn -> :noop end)
  end

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
