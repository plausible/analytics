defmodule PlausibleWeb.Live.Shields.IPAddressesTest do
  use PlausibleWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  alias Plausible.Shields

  setup [:create_user, :create_site, :log_in]

  describe "IP Rules - static" do
    test "renders ip rules page with empty list", %{conn: conn, site: site} do
      conn = get(conn, "/#{site.domain}/settings/shields/ip_addresses")
      resp = html_response(conn, 200)

      assert resp =~ "No IP Rules configured for this site"
      assert resp =~ "IP Block List"
    end

    test "lists ip rules with remove actions", %{conn: conn, site: site} do
      {:ok, r1} =
        Shields.add_ip_rule(site, %{"inet" => "127.0.0.1", "description" => "Alice"})

      {:ok, r2} =
        Shields.add_ip_rule(site, %{"inet" => "127.0.0.2", "description" => "Bob"})

      conn = get(conn, "/#{site.domain}/settings/shields/ip_addresses")
      resp = html_response(conn, 200)

      assert resp =~ "127.0.0.1"
      assert resp =~ "Alice"

      assert resp =~ "127.0.0.2"
      assert resp =~ "Bob"

      assert remove_button_1 = find(resp, "#remove-ip-rule-#{r1.id}")
      assert remove_button_2 = find(resp, "#remove-ip-rule-#{r2.id}")

      assert text_of_attr(remove_button_1, "phx-click" == "remove-ip-rule")
      assert text_of_attr(remove_button_1, "phx-value-rule-id" == r1.id)
      assert text_of_attr(remove_button_2, "phx-click" == "remove-ip-rule")
      assert text_of_attr(remove_button_2, "phx-value-rule-id" == r2.id)
    end

    test "add rule button is rendered", %{conn: conn, site: site} do
      conn = get(conn, "/#{site.domain}/settings/shields/ip_addresses")
      resp = html_response(conn, 200)

      assert element_exists?(resp, ~s/button#add-ip-rule[x-data]/)
      attr = text_of_attr(resp, ~s/button#add-ip-rule/, "x-on:click")

      assert attr =~ "open-modal"
      assert attr =~ "ip-rule-form-modal"
    end

    test "add rule button is not rendered when maximum reached", %{conn: conn, site: site} do
      for i <- 1..Shields.maximum_ip_rules() do
        assert {:ok, _} =
                 Shields.add_ip_rule(site, %{"inet" => "1.1.1.#{i}"})
      end

      conn = get(conn, "/#{site.domain}/settings/shields/ip_addresses")
      resp = html_response(conn, 200)

      refute element_exists?(resp, ~s/button#add-ip-rule[x-data]/)
      assert resp =~ "Maximum number of addresses reached"
      assert resp =~ "You've reached the maximum number of IP addresses you can block (30)"
    end
  end

  describe "IP Rules - LiveView" do
    test "modal contains form", %{site: site, conn: conn} do
      lv = get_liveview(conn, site)
      html = render(lv)

      assert element_exists?(
               html,
               ~s/form[phx-submit="save-ip-rule"] input[name="ip_rule\[inet\]"]/
             )

      assert element_exists?(
               html,
               ~s/form[phx-submit="save-ip-rule"] input[name="ip_rule\[description\]"]/
             )

      assert submit_button(html, ~s/form[phx-submit="save-ip-rule"]/)
    end

    test "form modal contains link to add own IP", %{site: site, conn: conn} do
      ip = PlausibleWeb.RemoteIP.get(conn)
      lv = get_liveview(conn, site)
      html = render(lv)

      assert text(html) =~ "Your current IP address is: #{ip}"
      assert element_exists?(html, ~s/a[phx-click="prefill-own-ip-rule"]/)
    end

    test "form modal does not contain link to add own IP if already added", %{
      site: site,
      conn: conn
    } do
      ip = PlausibleWeb.RemoteIP.get(conn)

      {:ok, _} =
        Shields.add_ip_rule(site, %{
          "inet" => ip,
          "description" => "Alice"
        })

      lv = get_liveview(conn, site)
      html = render(lv)

      refute text(html) =~ "Your current IP address is: #{ip}"
      refute element_exists?(html, ~s/a[phx-click="prefill-own-ip-rule"]/)
    end

    test "clicking the link prefills own IP", %{conn: conn, site: site, user: user} do
      lv = get_liveview(conn, site)
      lv |> element(~s/a[phx-click="prefill-own-ip-rule"]/) |> render_click()

      html = render(lv)

      assert text_of_attr(html, "input[name=\"ip_rule[inet]\"]", "value") ==
               PlausibleWeb.RemoteIP.get(conn)

      assert text_of_attr(html, "input[name=\"ip_rule[description]\"]", "value") == user.name
    end

    test "submitting own IP saves it", %{conn: conn, site: site, user: user} do
      ip = PlausibleWeb.RemoteIP.get(conn)
      assert [] = Shields.list_ip_rules(site)

      lv = get_liveview(conn, site)
      lv |> element(~s/a[phx-click="prefill-own-ip-rule"]/) |> render_click()
      lv |> element(~s/form/) |> render_submit()

      html = render(lv)

      assert html =~ ip
      assert html =~ user.name

      assert [%{id: id}] = Shields.list_ip_rules(site)

      tooltip = text_of_attr(html, "#inet-#{id}", "title")
      assert tooltip =~ "Added at #{Date.utc_today()}"
      assert tooltip =~ "by #{user.name} <#{user.email}>"

      assert [_] = Shields.list_ip_rules(site)
    end

    test "submitting a valid IP saves it", %{conn: conn, site: site} do
      lv = get_liveview(conn, site)

      lv
      |> element("form")
      |> render_submit(%{
        "ip_rule[inet]" => "1.1.1.1",
        "ip_rule[description]" => "A happy song"
      })

      html = render(lv)

      assert html =~ "1.1.1.1"
      assert html =~ "A happy song"

      assert [%{inet: ip, description: "A happy song"}] = Shields.list_ip_rules(site)
      assert to_string(ip) == "1.1.1.1"
    end

    test "submitting invalid IP renders error", %{conn: conn, site: site} do
      lv = get_liveview(conn, site)

      lv
      |> element("form")
      |> render_submit(%{
        "ip_rule[inet]" => "WRONG"
      })

      html = render(lv)
      assert html =~ "is invalid"
    end

    test "clicking Remove deletes the rule", %{conn: conn, site: site} do
      {:ok, _} =
        Shields.add_ip_rule(site, %{"inet" => "2.2.2.2", "description" => "Alice"})

      lv = get_liveview(conn, site)

      html = render(lv)
      assert html =~ "2.2.2.2"

      lv |> element(~s/button[phx-click="remove-ip-rule"]/) |> render_click()

      html = render(lv)
      refute html =~ "2.2.2.2"

      assert Shields.count_ip_rules(site) == 0
    end

    defp get_liveview(conn, site) do
      conn = assign(conn, :live_module, PlausibleWeb.Live.Shields)
      {:ok, lv, _html} = live(conn, "/#{site.domain}/settings/shields/ip_addresses")

      lv
    end
  end
end
