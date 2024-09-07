defmodule PlausibleWeb.ErrorViewTest do
  use PlausibleWeb.ConnCase, async: false

  test "renders 500.html", %{conn: conn} do
    conn = get(conn, "/test")
    layout = Application.get_env(:plausible, PlausibleWeb.Endpoint)[:render_errors][:layout]

    error_html =
      Phoenix.View.render_to_string(PlausibleWeb.ErrorView, "500.html",
        conn: conn,
        layout: layout
      )

    refute error_html =~ "data-domain="
  end

  test "renders json errors" do
    assert Phoenix.View.render_to_string(PlausibleWeb.ErrorView, "500.json", %{}) ==
             ~s[{"message":"Server error","status":500}]

    assert Phoenix.View.render_to_string(PlausibleWeb.ErrorView, "406.json", %{}) ==
             ~s[{"message":"Not Acceptable","status":406}]
  end
end
