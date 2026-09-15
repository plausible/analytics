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
    end
  end
end
