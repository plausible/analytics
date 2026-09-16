defmodule Plausible.OAuth.PKCE do
  @moduledoc """
  PKCE ([RFC 7636](https://www.rfc-editor.org/rfc/rfc7636.html)) verification for
  the authorization code flow.

  `S256` is mandatory here; `plain` is rejected, so a client cannot downgrade its
  way out of proving possession of the verifier.
  """

  # RFC 7636 section 4.1. The floor matters as much as the ceiling: the digest of
  # a short or empty verifier is guessable, which reduces PKCE to a no-op.
  @code_verifier_min_length 43
  @code_verifier_max_length 128

  @doc """
  Verifies a PKCE code verifier against a stored challenge. Only `S256` is
  accepted; `plain` and unknown methods are rejected.

  The verifier is refused unless it is #{@code_verifier_min_length}-#{@code_verifier_max_length}
  characters long ([RFC 7636 section 4.1](https://www.rfc-editor.org/rfc/rfc7636.html#section-4.1)),
  checked before the digest is computed so an out-of-range value costs no hash.

  The pair below is the worked example from
  [RFC 7636 appendix B](https://www.rfc-editor.org/rfc/rfc7636.html#appendix-B).

  The length bounds are checked before the digest, so a verifier outside them is
  refused even though it hashes to the challenge it is presented against.
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
