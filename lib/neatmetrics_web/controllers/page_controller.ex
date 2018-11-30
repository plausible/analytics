defmodule NeatmetricsWeb.PageController do
  use NeatmetricsWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def analytics(conn, %{"website" => website}) do
    render(conn, "analytics.html")
  end
end
