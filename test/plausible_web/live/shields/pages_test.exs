defmodule PlausibleWeb.Live.Shields.PagesTest do
  use PlausibleWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  alias Plausible.Shields

  setup [:create_user, :create_site, :log_in]

  describe "Page Rules - static" do
    test "renders page rules page with empty list", %{conn: conn, site: site} do
      conn = get(conn, "/#{site.domain}/settings/shields/pages")
      resp = html_response(conn, 200)

      assert resp =~ "No Page Rules configured for this site"
      assert resp =~ "Pages Block List"
    end

    test "lists page rules with remove actions", %{conn: conn, site: site} do
      {:ok, r1} =
        Shields.add_page_rule(site, %{"page_path" => "/test/1"})

      {:ok, r2} =
        Shields.add_page_rule(site, %{"page_path" => "/test/2"})

      conn = get(conn, "/#{site.domain}/settings/shields/pages")
      resp = html_response(conn, 200)

      assert resp =~ "/test/1"
      assert resp =~ "/test/2"

      assert remove_button_1 = find(resp, "#remove-page-rule-#{r1.id}")
      assert remove_button_2 = find(resp, "#remove-page-rule-#{r2.id}")

      assert text_of_attr(remove_button_1, "phx-click" == "remove-page-rule")
      assert text_of_attr(remove_button_1, "phx-value-rule-id" == r1.id)
      assert text_of_attr(remove_button_2, "phx-click" == "remove-page-rule")
      assert text_of_attr(remove_button_2, "phx-value-rule-id" == r2.id)
    end

    test "add rule button is rendered", %{conn: conn, site: site} do
      conn = get(conn, "/#{site.domain}/settings/shields/pages")
      resp = html_response(conn, 200)

      assert element_exists?(resp, ~s/button#add-page-rule[x-data]/)
      attr = text_of_attr(resp, ~s/button#add-page-rule/, "x-on:click")

      assert attr =~ "open-modal"
      assert attr =~ "page-rule-form-modal"
    end

    test "add rule button is not rendered when maximum reached", %{conn: conn, site: site} do
      for i <- 1..Shields.maximum_page_rules() do
        assert {:ok, _} =
                 Shields.add_page_rule(site, %{"page_path" => "/test/#{i}"})
      end

      conn = get(conn, "/#{site.domain}/settings/shields/pages")
      resp = html_response(conn, 200)

      refute element_exists?(resp, ~s/button#add-page-rule[x-data]/)
      assert resp =~ "Maximum number of pages reached"
      assert resp =~ "You've reached the maximum number of pages you can block (30)"
    end
  end

  describe "Page Rules - LiveView" do
    test "modal contains form", %{site: site, conn: conn} do
      lv = get_liveview(conn, site)
      html = render(lv)

      assert element_exists?(
               html,
               ~s/form[phx-submit="save-page-rule"] input[name="page_rule\[page_path\]"]/
             )

      assert submit_button(html, ~s/form[phx-submit="save-page-rule"]/)
    end

    test "submitting a valid Page saves it", %{conn: conn, site: site} do
      lv = get_liveview(conn, site)

      lv
      |> element("form")
      |> render_submit(%{
        "page_rule[page_path]" => "/test/**"
      })

      html = render(lv)

      assert html =~ "/test/**"

      assert [%{page_path: "/test/**"}] = Shields.list_page_rules(site)
    end

    test "submitting invalid Page renders error", %{conn: conn, site: site} do
      lv = get_liveview(conn, site)

      lv
      |> element("form")
      |> render_submit(%{
        "page_rule[page_path]" => "WRONG"
      })

      html = render(lv)
      assert html =~ "must start with /"
    end

    test "clicking Remove deletes the rule", %{conn: conn, site: site} do
      {:ok, _} =
        Shields.add_page_rule(site, %{"page_path" => "/test/*/page"})

      lv = get_liveview(conn, site)

      html = render(lv)
      assert html =~ "/test/*/page"

      lv |> element(~s/button[phx-click="remove-page-rule"]/) |> render_click()

      html = render(lv)
      refute html =~ "/test/*/page"

      assert Shields.count_page_rules(site) == 0
    end

    test "conclicting rules are annotated with a warning", %{conn: conn, site: site} do
      lv = get_liveview(conn, site)

      lv
      |> element("form")
      |> render_submit(%{
        "page_rule[page_path]" => "/test/*"
      })

      html = render(lv)
      refute html =~ "This rule might be redundant"

      lv
      |> element("form")
      |> render_submit(%{
        "page_rule[page_path]" => "/test/another"
      })

      html = render(lv)

      assert html =~ "/test/*"
      assert html =~ "/test/another"

      assert html =~
               "This rule might be redundant because the following rules may match first:\n\n/test/*"

      broader_rule_id =
        site
        |> Shields.list_page_rules()
        |> Enum.find(&(&1.page_path == "/test/*"))
        |> Map.fetch!(:id)

      lv |> element(~s/button#remove-page-rule-#{broader_rule_id}/) |> render_click()
      html = render(lv)

      assert html =~ "/test/another"
      refute html =~ "/test/*"

      refute html =~
               "This rule might be redundant because the following rules may match first:\n\n/test/*"
    end

    defp get_liveview(conn, site) do
      conn = assign(conn, :live_module, PlausibleWeb.Live.Shields)
      {:ok, lv, _html} = live(conn, "/#{site.domain}/settings/shields/pages")

      lv
    end
  end
end
