defmodule Plausible.Sentry.Client do
  @behaviour Sentry.HTTPClient

  defguard is_redirect(status) when is_integer(status) and status >= 300 and status < 400

  require Logger

  defmodule DummyChild do
    @moduledoc """
    The Sentry.HTTPClient behaviour requires a child spec to be supplied.
    In this case we don't want Sentry to manage our Finch instances, hence it's fed
    with a dummy module for the sake of the contract.
    """
    use Agent

    def start_link(:noop) do
      Agent.start_link(fn -> nil end, name: __MODULE__)
    end
  end

  def child_spec do
    DummyChild.child_spec(:noop)
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
        Logger.error("Sentry returned a redirect that is not handled yet.")
        {:error, :stop}

      {:ok, %{status: status, body: body, headers: headers}} ->
        {:ok, status, headers, body}

      {:error, error} = e ->
        Logger.error("Sentry call failed with: #{inspect(error)}")
        e
    end
  end
end
