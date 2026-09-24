defmodule PlausibleWeb.VerifiedRoutes do
  @moduledoc """
  Convenience macro to be used everywhere where verified routes are used.
  """
  use Plausible

  defmacro __using__(_) do
    # Follows the same logic as `Plug.Static` setup in `PlausibleWeb.Endpoint`
    static_paths = ~w(css js images favicon.ico)

    static_paths =
      on_ee do
        static_paths
      else
        static_paths ++ ["robots.txt"]
      end

    quote do
      use Phoenix.VerifiedRoutes,
        router: PlausibleWeb.Router,
        endpoint: PlausibleWeb.Endpoint,
        statics: unquote(static_paths)

      import unquote(__MODULE__)
    end
  end

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
