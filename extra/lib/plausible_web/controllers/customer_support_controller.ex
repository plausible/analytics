defmodule PlausibleWeb.CustomerSupportController do
  use PlausibleWeb, :controller

  def redirect_to_root(conn, _params) do
    redirect(conn, to: "/cs")
  end
end
