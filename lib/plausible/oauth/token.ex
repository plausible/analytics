defmodule Plausible.OAuth.Token do
  @moduledoc """
  Helpers for generating and hashing OAuth tokens and authorization codes.

  Raw tokens are prefixed with a plain-text identifier so that secret scanners
  (e.g. GitHub secret scanning) can detect accidentally leaked credentials,
  mirroring `Plausible.Plugins.API.Token`. Only the hash and a short,
  non-sensitive prefix are ever persisted - the raw value is returned once at
  creation time and never stored.
  """

  use Plausible

  # Number of leading characters of the raw token stored for support/debugging.
  @prefix_length 20

  @type kind() :: :access | :refresh | :code

  @doc """
  Generates a random, prefixed token of the given kind.

  Returns a map with the `:raw` value (to be handed to the client once),
  its `:hash` (to be persisted), and a short `:prefix` (safe to persist and
  display).
  """
  @spec generate(kind()) :: %{raw: String.t(), hash: String.t(), prefix: String.t()}
  def generate(kind) do
    random = :crypto.strong_rand_bytes(64) |> Base.url_encode64() |> binary_part(0, 64)
    raw = "#{prefix(kind)}-#{random}"

    %{
      raw: raw,
      hash: hash(raw),
      prefix: binary_part(raw, 0, @prefix_length)
    }
  end

  @doc """
  Hashes a raw token/code. Reuses the salted SHA-256 scheme used for API keys
  so that lookups are constant across the codebase.
  """
  @spec hash(String.t()) :: String.t()
  def hash(raw), do: Plausible.Auth.ApiKey.do_hash(raw)

  @doc """
  Secret-scanner-friendly plain-text prefix for each token kind.
  """
  @spec prefix(kind()) :: String.t()
  def prefix(kind) do
    suffix =
      case kind do
        :access -> "at"
        :refresh -> "rt"
        :code -> "ac"
      end

    base =
      on_ee do
        case Application.get_env(:plausible, :environment) do
          "prod" -> "plausible-mcp"
          env -> "plausible-mcp-#{env}"
        end
      else
        "plausible-mcp-selfhost"
      end

    "#{base}-#{suffix}"
  end
end
