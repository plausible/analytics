defmodule PlausibleWeb.InternalEndpoint do
  use Sentry.PlugCapture
  use Phoenix.Endpoint, otp_app: :plausible

  plug(PlausibleWeb.InternalRouter)
end
