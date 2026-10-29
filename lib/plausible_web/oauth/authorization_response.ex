defmodule PlausibleWeb.OAuth.AuthorizationResponse do
  @moduledoc """
  Builds the [authorization response](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-v2-1#name-authorization-response)
  URL the user agent is redirected to, carrying either a code or an error.

  The `redirect_uri` is appended to rather than rebuilt: it has already been
  matched against the client's registered URIs, so its own query - which the
  client is entitled to see back byte for byte - is preserved verbatim.
  """

  @doc """
  Appends response parameters to a validated `redirect_uri`.

  Parameters with a `nil` value are dropped, so an absent `state` does not
  become `state=`.
  """
  @spec redirect_url(String.t(), keyword()) :: String.t()
  def redirect_url(redirect_uri, params) do
    query = params |> Enum.reject(fn {_k, v} -> is_nil(v) end) |> URI.encode_query()
    uri = URI.parse(redirect_uri)

    merged =
      case uri.query do
        empty when empty in [nil, ""] -> query
        existing -> existing <> "&" <> query
      end

    URI.to_string(%{uri | query: merged})
  end
end
