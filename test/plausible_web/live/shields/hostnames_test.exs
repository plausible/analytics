defmodule PlausibleWeb.Live.Shields.HostnamesTest do
  use PlausibleWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  alias Plausible.Shields

  setup [:create_user, :create_site, :log_in]

  describe "Hostname Rules - static" do
    test "renders hostname rules hostname with empty list", %{conn: conn, site: site} do
      conn = get(conn, "/#{site.domain}/settings/shields/hostnames")
      resp = html_response(conn, 200)

      assert resp =~ "No Hostname Rules configured for this site"
      assert resp =~ "Hostnames Allow List"
      assert resp =~ "Traffic from all hostnames is currently accepted."
    end

    test "lists hostname rules with remove actions", %{conn: conn, site: site} do
      {:ok, r1} =
        Shields.add_hostname_rule(site, %{"hostname" => "example.com"})

      {:ok, r2} =
        Shields.add_hostname_rule(site, %{"hostname" => "example.org"})

      conn = get(conn, "/#{site.domain}/settings/shields/hostnames")
      resp = html_response(conn, 200)

      assert resp =~ "example.com"
      assert resp =~ "example.org"

      assert remove_button_1 = find(resp, "#remove-hostname-rule-#{r1.id}")
      assert remove_button_2 = find(resp, "#remove-hostname-rule-#{r2.id}")

      assert text_of_attr(remove_button_1, "phx-click" == "remove-hostname-rule")
      assert text_of_attr(remove_button_1, "phx-value-rule-id" == r1.id)
      assert text_of_attr(remove_button_2, "phx-click" == "remove-hostname-rule")
      assert text_of_attr(remove_button_2, "phx-value-rule-id" == r2.id)
    end

    test "add rule button is rendered", %{conn: conn, site: site} do
      conn = get(conn, "/#{site.domain}/settings/shields/hostnames")
      resp = html_response(conn, 200)

      assert element_exists?(resp, ~s/button#add-hostname-rule[x-data]/)
      attr = text_of_attr(resp, ~s/button#add-hostname-rule/, "x-on:click")

      assert attr =~ "open-modal"
      assert attr =~ "hostname-rule-form-modal"
    end

    test "add rule button is not rendered when maximum reached", %{conn: conn, site: site} do
      for i <- 1..Shields.maximum_hostname_rules() do
        assert {:ok, _} =
                 Shields.add_hostname_rule(site, %{"hostname" => "#{i}.example.com"})
      end

      conn = get(conn, "/#{site.domain}/settings/shields/hostnames")
      resp = html_response(conn, 200)

      refute element_exists?(resp, ~s/button#add-hostname-rule[x-data]/)
      assert resp =~ "Maximum number of hostnames reached"
      assert resp =~ "You've reached the maximum number of hostnames you can block (10)"
    end
  end

  describe "Hostname Rules - LiveView" do
    test "modal contains form", %{site: site, conn: conn} do
      lv = get_liveview(conn, site)
      html = render(lv)

      assert element_exists?(
               html,
               ~s/form[phx-submit="save-hostname-rule"] input[name="hostname_rule\[hostname\]"]/
             )

      assert submit_button(html, ~s/form[phx-submit="save-hostname-rule"]/)
    end

    test "if no rules are added yet, form displays hint", %{site: site, conn: conn} do
      lv = get_liveview(conn, site)
      html = render(lv)

      assert text(html) =~
               "NB: Once added, we will start rejecting traffic from non-matching hostnames within a few minutes."

      refute text(html) =~ "we will start accepting"
    end

    test "if rules are added, form changes the hint", %{site: site, conn: conn} do
      {:ok, _} =
        Shields.add_hostname_rule(site, %{"hostname" => "*.example.com"})

      lv = get_liveview(conn, site)
      html = render(lv)

      refute text(html) =~ "we will start rejecting traffic"

      assert text(html) =~
               "Once added, we will start accepting traffic from this hostname within a few minutes."
    end

    test "submitting a valid Hostname saves it", %{conn: conn, site: site} do
      lv = get_liveview(conn, site)

      lv
      |> element("form")
      |> render_submit(%{
        "hostname_rule[hostname]" => "*.example.com"
      })

      html = render(lv)

      assert html =~ "*.example.com"

      assert [%{hostname: "*.example.com"}] = Shields.list_hostname_rules(site)
    end

    test "submitting invalid Hostname renders error", %{conn: conn, site: site} do
      lv = get_liveview(conn, site)

      lv
      |> element("form")
      |> render_submit(%{
        "hostname_rule[hostname]" => :binary.copy("a", 256)
      })

      html = render(lv)
      assert html =~ "should be at most 250 character(s)"
    end

    test "clicking Remove deletes the rule", %{conn: conn, site: site} do
      {:ok, _} =
        Shields.add_hostname_rule(site, %{"hostname" => "*.example.com"})

      lv = get_liveview(conn, site)

      html = render(lv)
      assert html =~ "*.example.com"

      lv |> element(~s/button[phx-click="remove-hostname-rule"]/) |> render_click()

      html = render(lv)
      refute html =~ "*.example.com"

      assert Shields.count_hostname_rules(site) == 0
    end

    test "conclicting rules are annotated with a warning", %{conn: conn, site: site} do
      lv = get_liveview(conn, site)

      lv
      |> element("form")
      |> render_submit(%{
        "hostname_rule[hostname]" => "*example.com"
      })

      html = render(lv)
      refute html =~ "This rule might be redundant"

      lv
      |> element("form")
      |> render_submit(%{
        "hostname_rule[hostname]" => "subdomain.example.com"
      })

      html = render(lv)

      assert html =~ "*example.com"
      assert html =~ "subdomain.example.com"

      assert html =~
               "This rule might be redundant because the following rules may match first:\n\n*example.com"

      broader_rule_id =
        site
        |> Shields.list_hostname_rules()
        |> Enum.find(&(&1.hostname == "*example.com"))
        |> Map.fetch!(:id)

      lv |> element(~s/button#remove-hostname-rule-#{broader_rule_id}/) |> render_click()
      html = render(lv)

      assert html =~ "subdomain.example.com"
      refute html =~ "*example.com"
      refute html =~ "This rule might be redundant"
    end

    defp get_liveview(conn, site) do
      conn = assign(conn, :live_module, PlausibleWeb.Live.Shields)
      {:ok, lv, _html} = live(conn, "/#{site.domain}/settings/shields/hostnames")

      lv
    end
  end
end
