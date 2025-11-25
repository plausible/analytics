defmodule Plausible.InstallationSupport.URL do
  @moduledoc """
  URL utilities for installation support, including cache busting functionality.
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
