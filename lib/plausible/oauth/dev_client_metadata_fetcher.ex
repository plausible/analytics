defmodule Plausible.OAuth.DevClientMetadataFetcher do
  @moduledoc """
  **Development-only** fetcher for CIMD documents, used for local end-to-end
  testing of the MCP connector before the shared SSRF-safe HTTP helper lands.

  This performs a plain outbound GET with **no SSRF protection** (no private/
  loopback/link-local IP blocking, no DNS-rebind defense). It must never be used
  in production - `get/1` raises if the configured environment is `prod`. Wire it
  only from `config/dev.exs`:

      config :plausible, Plausible.OAuth,
        client_metadata_fetcher: Plausible.OAuth.DevClientMetadataFetcher

  Once the SSRF-safe helper is available, replace this with a fetcher built on
  top of it and delete this module.
  """

  @max_body_bytes 1_000_000
  @timeout_ms 5_000

  @spec get(String.t()) :: {:ok, String.t()} | {:error, atom()}
  def get(url) do
    if Application.get_env(:plausible, :environment) == "prod" do
      raise "#{inspect(__MODULE__)} must not be used in production - it performs an unguarded SSRF-prone fetch"
    end

    result =
      Req.new(
        url: url,
        finch: Plausible.Finch,
        max_redirects: 3,
        receive_timeout: @timeout_ms
      )
      |> Req.get()

    case result do
      {:ok, %Req.Response{status: 200, body: body}} ->
        body = if is_binary(body), do: body, else: Jason.encode!(body)

        if byte_size(body) > @max_body_bytes do
          {:error, :client_metadata_too_large}
        else
          {:ok, body}
        end

      {:ok, %Req.Response{}} ->
        {:error, :client_metadata_unavailable}

      {:error, _reason} ->
        {:error, :client_metadata_unreachable}
    end
  end
end
