defmodule Plausible.OAuth.PKCE do
  @moduledoc """
  PKCE ([RFC 7636](https://www.rfc-editor.org/rfc/rfc7636.html)) verification for
  the authorization code flow.
  """

  # RFC 7636 section 4.1. The floor matters as much as the ceiling: the digest of
  # a short or empty verifier is guessable, which reduces PKCE to a no-op.
  @code_verifier_min_length 43
  @code_verifier_max_length 128

  @doc """
  Verifies a code verifier against a stored challenge.
  Only `S256` is accepted; `plain` and unknown methods are rejected.

  The verifier must be #{@code_verifier_min_length}-#{@code_verifier_max_length}
  characters long. Checked before the digest, so an out-of-range verifier is
  refused even when it hashes to the challenge.
  """
  @spec verify(String.t(), String.t() | nil, String.t()) :: :ok | {:error, :invalid_grant}
  def verify(challenge, verifier, "S256")
      when is_binary(challenge) and is_binary(verifier) and
             byte_size(verifier) >= @code_verifier_min_length and
             byte_size(verifier) <= @code_verifier_max_length do
    computed = :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false)

    if Plug.Crypto.secure_compare(computed, challenge) do
      :ok
    else
      {:error, :invalid_grant}
    end
  end

  def verify(_challenge, _verifier, _method), do: {:error, :invalid_grant}
end
