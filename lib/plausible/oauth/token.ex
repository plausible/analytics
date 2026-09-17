defmodule Plausible.OAuth.Token do
  @moduledoc """
  Generates and hashes OAuth access tokens and authorization codes.

  Only the hash and a short trailing hint are persisted - the raw value is
  returned once at creation and never stored.
  """

  use Plausible

  # Bytes of entropy; the encoded value is truncated back to this many characters.
  @random_length 64
  @hint_length 4

  @type kind() :: :access | :refresh | :code

  @doc """
  Generates a random, prefixed value of the given kind, returning the `:raw`
  value to hand out once, its `:hash` to persist, and a displayable `:hint`.
  """
  @spec generate(kind()) :: %{raw: String.t(), hash: String.t(), hint: String.t()}
  def generate(kind) do
    raw = "#{plaintext_prefix(kind)}-#{random_value()}"

    %{raw: raw, hash: hash(raw), hint: String.slice(raw, -@hint_length, @hint_length)}
  end

  @doc """
  Hashes a raw token or code.
  """
  @spec hash(String.t()) :: String.t()
  def hash(raw) when is_binary(raw) do
    :crypto.hash(:sha256, raw)
    |> Base.encode16()
    |> String.downcase()
  end

  @doc """
  Plain-text prefix identifying the kind of value and the environment, so that
  tools like GitHub secret scanning can spot a leaked token.
  """
  @spec plaintext_prefix(kind()) :: String.t()
  def plaintext_prefix(kind) do
    extra =
      case kind do
        :access -> "at"
        :refresh -> "rt"
        :code -> "ac"
      end

    on_ee do
      case Application.get_env(:plausible, :environment) do
        "prod" -> "plausible-oauth-#{extra}"
        env -> "plausible-oauth-#{extra}-#{env}"
      end
    else
      "plausible-oauth-#{extra}-selfhost"
    end
  end

  defp random_value() do
    :crypto.strong_rand_bytes(@random_length)
    |> Base.url_encode64()
    |> binary_part(0, @random_length)
  end
end
