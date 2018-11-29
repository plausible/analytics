defmodule NeatmetricsWeb.PageController do
  use NeatmetricsWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
