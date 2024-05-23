defmodule Plausible.Verification.URL do
  @moduledoc """
  Busting some caches by appending ?plausible_verification=12345 to it.
  """

  def bust_url(url) do
    cache_invalidator = abs(:erlang.unique_integer())
    update_url(url, cache_invalidator)
  end

  defp update_url(url, invalidator) do
    url
    |> URI.parse()
    |> then(fn uri ->
      updated_query =
        (uri.query || "")
        |> URI.decode_query()
        |> Map.put("plausible_verification", invalidator)
        |> URI.encode_query()

      struct!(uri, query: updated_query)
    end)
    |> to_string()
  end
end
