defmodule PlausibleWeb.Live.CustomerSupportTest do
  use PlausibleWeb.ConnCase, async: true
  use Plausible.Teams.Test
  use Plausible
  @moduletag :ee_only

  on_ee do
    @cs_index Routes.customer_support_path(PlausibleWeb.Endpoint, :index)

    import Phoenix.LiveViewTest
    import Plausible.Test.Support.HTML

    describe "unauthenticated" do
      test "not allowed if not logged in", %{conn: conn} do
        conn = get(conn, @cs_index)
        assert response(conn, 403) == "Not allowed"
      end
    end

    describe "authenticated regular user" do
      test "not allowed if not superadmin", %{conn: conn} do
        conn = get(conn, @cs_index)
        assert response(conn, 403) == "Not allowed"
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
    end

    defp assert_search_result(doc, type, id) do
      assert [link] = find(doc, ~s|a[data-test-type="#{type}"][data-test-id="#{id}"]|)

      assert text_of_attr(link, "href") ==
               Routes.customer_support_resource_path(
                 PlausibleWeb.Endpoint,
                 :details,
                 "#{type}s",
                 type,
                 id
               )
    end

    defp refute_search_result(doc, type, id) do
      assert find(doc, ~s|a[data-test-type="#{type}"][data-test-id="#{id}"]|) == []
    end
  end

  defp type_into_input(lv, id, text) do
    lv
    |> element("form#filter-form")
    |> render_change(%{id => text})
  end
end
