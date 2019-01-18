defmodule PlausibleWeb.ApiController do
  use PlausibleWeb, :controller
  require Logger

  def page(conn, _params) do
    with {:ok, _pageview} <- create_pageview(conn)
    do
      conn |> send_resp(202, "")
    else
      {:error, changeset} ->
        Logger.info("Error processing pageview: #{inspect(changeset)}")
        conn |> send_resp(400, "")
    end
  end

  defp create_pageview(conn) do
    body = parse_body(conn)
    pageview = process_pageview(body, conn)
    if !bot?(pageview) do
      Plausible.Pageview.changeset(%Plausible.Pageview{}, pageview)
        |> Plausible.Repo.insert
    else
      {:ok, nil}
    end
  end

  defp process_pageview(params, conn) do
    uri = URI.parse(params["url"] || "")
    user_agent = Plug.Conn.get_req_header(conn, "user-agent") |> List.first

    %{
      hostname: strip_www(uri.host),
      pathname: uri.path,
      user_agent: user_agent,
      referrer: params["referrer"],
      new_visitor: params["new_visitor"],
      screen_width: params["screen_width"],
      screen_height: params["screen_height"],
      session_id: params["sid"],
      user_id: params["uid"]
    }
  end

  defp parse_body(conn) do
    {:ok, body, _conn} = Plug.Conn.read_body(conn)
    Jason.decode!(body)
  end

  defp bot?(pageview) do
    pageview.user_agent && UAInspector.bot?(pageview.user_agent)
  end

  defp strip_www(nil), do: nil
  defp strip_www(hostname) do
    String.replace_prefix(hostname, "www.", "")
  end
end
