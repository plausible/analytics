defmodule PlausibleWeb.AvatarController do
  @moduledoc """
  This module proxies requests to BASE_URL/avatar/:hash to www.gravatar.com/avatar/:hash.

  The purpose is to make use of Gravatar's convenient avatar service without exposing information
  that could be used for tracking the Plausible user. Compared to requesting the Gravatar directly
  from the browser, this proxy module protects the Plausible user from disclosing to Gravatar:
  1. The client IP address
  2. User-Agent
  3. Referer header which can be used to track which site the user is visiting (i.e. plausible.io or self-hosted URL)

  The downside is the added latency from the request having to go through the Plausible server, rather than contacting the
  local CDN server operated by Gravatar's service.
  """
  use PlausibleWeb, :controller
  alias Plausible.HTTPClient

  @gravatar_base_url "https://www.gravatar.com"
  def avatar(conn, params) do
    url = Path.join(@gravatar_base_url, ["avatar/", params["hash"]]) <> "?s=150&d=identicon"

    case HTTPClient.impl().get(url) do
      {:ok, %Finch.Response{status: 200, body: body, headers: headers}} ->
        conn
        |> forward_headers(headers)
        |> send_resp(200, body)

      {:error, _} ->
        send_resp(conn, 400, "")
    end
  end

  @forwarded_headers ["content-type", "cache-control", "expires"]
  defp forward_headers(conn, headers) do
    headers_to_forward = Enum.filter(headers, fn {k, _} -> k in @forwarded_headers end)
    %Plug.Conn{conn | resp_headers: headers_to_forward}
  end
end
