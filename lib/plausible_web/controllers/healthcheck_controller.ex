defmodule PlausibleWeb.HealthCheckController do
  use PlausibleWeb, :controller

  def index(conn, _params) do
    json(conn, %{status: "RUNNING", version: List.to_string(Application.spec(:plausible)[:vsn]), timestamp: DateTime.to_unix(DateTime.utc_now()), name: "plausible"})
  end
end
