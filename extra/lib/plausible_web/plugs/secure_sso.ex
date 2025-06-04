defmodule PlausibleWeb.Plugs.SecureSSO do
  @moduledoc """
  Plug for securing SSO routes by setting proper policies in headers.
  """

  alias PlausibleWeb.Router.Helpers, as: Routes

  @csp """
       default-src 'none';
       script-src 'self' 'nonce-<%= nonce %>' 'report-sample';
       img-src 'self' 'report-sample';
       report-uri <%= report_path %>;
       report-to csp-report-endpoint
       """
       |> String.replace("\n", " ")

  @behaviour Plug
  import Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _) do
    nonce = :crypto.strong_rand_bytes(18) |> Base.encode64()
    csp_report_path = Routes.sso_path(conn, :csp_report)

    conn
    |> put_private(:sso_nonce, nonce)
    |> Phoenix.Controller.put_secure_browser_headers(%{
      "cache-control" => "no-cache, no-store, must-revalidate",
      "pragma" => "no-cache",
      "reporting-endpoints" => "csp-report-endpoint=\"#{csp_report_path}\"",
      "content-security-policy" =>
        EEx.eval_string(@csp, nonce: nonce, report_path: csp_report_path),
      "x-xss-protection" => "1; mode=block"
    })
  end
end
