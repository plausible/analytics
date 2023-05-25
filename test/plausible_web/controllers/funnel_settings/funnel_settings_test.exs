defmodule PlausibleWeb.FunnelSettingsTest do
  use PlausibleWeb.ConnCase, async: false

  describe "GET /:website/settings/funnels" do
    setup [:create_user, :log_in, :create_site]

    test "lists funnels for the site and renders help link", %{conn: conn, site: site} do
      :ok = setup_funnels(site)
      conn = get(conn, "/#{site.domain}/settings/funnels")

      resp = html_response(conn, 200)
      assert resp =~ "Compose goals into funnels"
      assert resp =~ "From blog to signup"
      assert resp =~ "From signup to blog"
      doc = Floki.parse_document!(resp)

      assert [{"a", _, _}] = Floki.find(doc, "a[href=\"https://plausible.io/docs/funnels\"]")
    end

    test "if goals are present, Add Funnel button is rendered", %{conn: conn, site: site} do
      :ok = setup_funnels(site)
      conn = get(conn, "/#{site.domain}/settings/funnels")
      doc = conn |> html_response(200) |> Floki.parse_document!()
      assert [_] = Floki.find(doc, ~S/button[phx-click="add-funnel"]/)
    end
  end

  defp setup_funnels(site) do
    {:ok, g1} = Plausible.Goals.create(site, %{"page_path" => "/go/to/blog/**"})
    {:ok, g2} = Plausible.Goals.create(site, %{"event_name" => "Signup"})

    {:ok, _} =
      Plausible.Funnels.create(
        site,
        "From blog to signup",
        [%{"goal_id" => g1.id}, %{"goal_id" => g2.id}]
      )

    {:ok, _} =
      Plausible.Funnels.create(
        site,
        "From signup to blog",
        [%{"goal_id" => g2.id}, %{"goal_id" => g1.id}]
      )

    :ok
  end
end
