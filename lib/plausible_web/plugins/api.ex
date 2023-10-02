defmodule PlausibleWeb.Plugins.API do
  @moduledoc """
  Plausible Plugins API
  """

  @doc """
  Returns the API base URI, so that complete URLs can
  be generated from forwared Router helpers.
  """
  @spec base_uri() :: URI.t()
  def base_uri() do
    PlausibleWeb.Endpoint.url()
    |> Path.join("/api/plugins")
    |> URI.new!()
  end
end
