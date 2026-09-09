defmodule PlausibleWeb.VerifiedRoutes do
  defmacro __using__(_) do
    quote do
      use Phoenix.VerifiedRoutes,
        router: PlausibleWeb.Router,
        endpoint: PlausibleWeb.Endpoint,
        statics: ~w(css js images favicon.ico)
    end
  end
end
