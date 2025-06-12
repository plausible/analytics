defmodule PlausibleWeb.Live.CustomerSupportTest do
  use PlausibleWeb.ConnCase, async: false
  use Plausible.Teams.Test
  use Plausible
  @moduletag :ee_only

  on_ee do
    alias PlausibleWeb.InternalRouter.Helpers, as: InternalRoutes
    @endpoint PlausibleWeb.InternalEndpoint
    @cs_index InternalRoutes.customer_support_path(PlausibleWeb.InternalEndpoint, :index)

    import Phoenix.LiveViewTest
    import Plausible.Test.Support.HTML

    describe "unauthenticated" do
      test "not allowed if not logged in", %{conn: conn} do
        conn = get(conn, @cs_index)
        assert redirected_to(conn, 302) == "/login"
      end
    end

    describe "authenticated regular user" do
      test "not allowed if not superadmin", %{conn: conn} do
        conn = get(conn, @cs_index)
        assert redirected_to(conn, 302) == "/login"
      end
    end

    describe "authenticated superadmin" do
      setup [:create_user, :log_in, :create_site]

      setup %{user: user} do
        patch_env(:super_admin_user_ids, [user.id])
      end

      test "lists resources", %{conn: conn, site: site, user: user} do
        conn = get(conn, @cs_index)
        resp = html_response(conn, 200)
        team = team_of(user)
        assert_search_result(resp, "site", site.id)
        assert_search_result(resp, "team", team.id)
        assert_search_result(resp, "user", user.id)
      end

      test "filters as you type", %{conn: conn, site: site, user: user} do
        site2 = new_site(owner: user, domain: "hello.example.com")
        {:ok, lv, _html} = live(conn, @cs_index)
        type_into_input(lv, "filter-text", "hello")

        html = render(lv)

        assert_search_result(html, "site", site2.id)
        refute_search_result(html, "site", site.id)

        type_into_input(lv, "filter-text", "user:hello")
        html = render(lv)

        refute_search_result(html, "site", site2.id)

        type_into_input(lv, "filter-text", "site:hello")
        html = render(lv)

        assert_search_result(html, "site", site2.id)
      end

      test "search teams", %{conn: conn} do
        team1 = new_user(team: [name: "Team One"]) |> team_of()

        team2 =
          new_user(team: [name: "Team Two"])
          |> subscribe_to_growth_plan()
          |> team_of()

        team3 = new_user(team: [name: "Team Three"]) |> team_of()

        {:ok, lv, _html} = live(conn, @cs_index)

        type_into_input(lv, "filter-text", "team:Team")
        html = render(lv)

        assert_search_result(html, "team", team1.id)
        assert_search_result(html, "team", team2.id)
        assert_search_result(html, "team", team3.id)

        type_into_input(lv, "filter-text", "team:Team T")
        html = render(lv)

        refute_search_result(html, "team", team1.id)
        assert_search_result(html, "team", team2.id)
        assert_search_result(html, "team", team3.id)

        type_into_input(lv, "filter-text", "team:Team T +sub")
        html = render(lv)

        refute_search_result(html, "team", team1.id)
        assert_search_result(html, "team", team2.id)
        refute_search_result(html, "team", team3.id)
      end
    end

    defp assert_search_result(doc, type, id) do
      assert [link] = find(doc, ~s|a[data-test-type="#{type}"][data-test-id="#{id}"]|)

      assert text_of_attr(link, "href") ==
               InternalRoutes.customer_support_resource_path(
                 PlausibleWeb.InternalEndpoint,
                 :details,
                 "#{type}s",
                 type,
                 id
               )
    end

    defp refute_search_result(doc, type, id) do
      assert find(doc, ~s|a[data-test-type="#{type}"][data-test-id="#{id}"]|) == []
    end

    defp type_into_input(lv, id, text) do
      lv
      |> element("form#filter-form")
      |> render_change(%{id => text})
    end
  end
end
