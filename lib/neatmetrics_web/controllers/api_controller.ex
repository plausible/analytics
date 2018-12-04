defmodule NeatmetricsWeb.ApiController do
  use NeatmetricsWeb, :controller

  def page(conn, _params) do
    {:ok, pageview} = create_pageview(conn)
    conn |> send_resp(200, "")
  end

  defp create_pageview(conn) do
    body = parse_body(conn)
    pageview = process_pageview(body)
    Neatmetrics.Pageview.changeset(%Neatmetrics.Pageview{}, pageview)
      |> Neatmetrics.Repo.insert
  end

  defp process_pageview(params) do
    uri = URI.parse(params["url"])

    %{
      hostname: uri.host,
      pathname: uri.path,
      referrer: params["referrer"],
      user_agent: params["user_agent"],
      screen_width: params["screen_width"],
      screen_height: params["screen_height"]
    }
  end

  defp parse_body(conn) do
    {:ok, body, conn} = Plug.Conn.read_body(conn)
    Jason.decode!(body)
  end
end
