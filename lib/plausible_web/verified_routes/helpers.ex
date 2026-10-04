defmodule PlausibleWeb.VerifiedRoutes.Helpers do
  @moduledoc """
  Path and URL helpers imported by `use PlausibleWeb.VerifiedRoutes`.

  Kept apart from `PlausibleWeb.VerifiedRoutes` on purpose: modules that
  `use PlausibleWeb.VerifiedRoutes` depend on it at compile time, so it must not
  reference the router or endpoint at runtime. Otherwise a change to almost any
  module would recompile every module that uses verified routes.
  """

  def stats_path(domain, params \\ []) when is_binary(domain) and byte_size(domain) > 0 do
    Phoenix.VerifiedRoutes.unverified_path(
      PlausibleWeb.Endpoint,
      PlausibleWeb.Router,
      "/#{encode_segment(domain)}",
      params
    )
  end

  def shared_stats_path(domain, params \\ [], star_path \\ nil)
      when is_binary(domain) and byte_size(domain) > 0 do
    path = "/share/#{encode_segment(domain)}/"

    path =
      if is_list(star_path) and star_path != [] do
        path <> encode_path(star_path)
      else
        path
      end

    Phoenix.VerifiedRoutes.unverified_path(
      PlausibleWeb.Endpoint,
      PlausibleWeb.Router,
      path,
      params
    )
  end

  def stats_url(domain, params \\ []) when is_binary(domain) and byte_size(domain) > 0 do
    Phoenix.VerifiedRoutes.unverified_url(
      PlausibleWeb.Endpoint,
      "/#{URI.encode_www_form(domain)}",
      params
    )
  end

  defp encode_path([str | _] = path) when is_binary(str) do
    Enum.map_join(path, "/", &encode_segment/1)
  end

  defp encode_segment(data) do
    data
    |> Phoenix.Param.to_param()
    |> URI.encode(&URI.char_unreserved?/1)
  end
end
