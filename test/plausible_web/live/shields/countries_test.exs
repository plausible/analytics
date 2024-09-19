defmodule PlausibleWeb.Live.Shields.CountriesTest do
  use PlausibleWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  alias Plausible.Shields

  setup [:create_user, :create_site, :log_in]

  describe "Country Rules - static" do
    test "renders country rules page with empty list", %{conn: conn, site: site} do
      conn = get(conn, "/#{site.domain}/settings/shields/countries")
      resp = html_response(conn, 200)

      assert resp =~ "No Country Rules configured for this site"
      assert resp =~ "Country Block List"
    end

    test "lists country rules with remove actions", %{conn: conn, site: site} do
      {:ok, r1} =
        Shields.add_country_rule(site, %{"country_code" => "PL"})

      {:ok, r2} =
        Shields.add_country_rule(site, %{"country_code" => "EE"})

      conn = get(conn, "/#{site.domain}/settings/shields/countries")
      resp = html_response(conn, 200)

      assert resp =~ "Poland"
      assert resp =~ "Estonia"

      assert remove_button_1 = find(resp, "#remove-country-rule-#{r1.id}")
      assert remove_button_2 = find(resp, "#remove-country-rule-#{r2.id}")

      assert text_of_attr(remove_button_1, "phx-click" == "remove-country-rule")
      assert text_of_attr(remove_button_1, "phx-value-rule-id" == r1.id)
      assert text_of_attr(remove_button_2, "phx-click" == "remove-country-rule")
      assert text_of_attr(remove_button_2, "phx-value-rule-id" == r2.id)
    end

    test "add rule button is rendered", %{conn: conn, site: site} do
      conn = get(conn, "/#{site.domain}/settings/shields/countries")
      resp = html_response(conn, 200)

      assert element_exists?(resp, ~s/button#add-country-rule[x-data]/)
      attr = text_of_attr(resp, ~s/button#add-country-rule/, "x-on:click")

      assert attr =~ "open-modal"
      assert attr =~ "country-rule-form-modal"
    end

    test "add rule button is not rendered when maximum reached", %{conn: conn, site: site} do
      country_codes =
        Location.Country.all()
        |> Enum.take(Shields.maximum_country_rules())
        |> Enum.map(& &1.alpha_2)

      for cc <- country_codes do
        assert {:ok, _} =
                 Shields.add_country_rule(site, %{"country_code" => "#{cc}"})
      end

      conn = get(conn, "/#{site.domain}/settings/shields/countries")
      resp = html_response(conn, 200)

      refute element_exists?(resp, ~s/button#add-country-rule[x-data]/)
      assert resp =~ "Maximum number of countries reached"
      assert resp =~ "You've reached the maximum number of countries you can block (30)"
    end
  end

  describe "Country Rules - LiveView" do
    test "modal contains form", %{site: site, conn: conn} do
      lv = get_liveview(conn, site)
      html = render(lv)

      assert element_exists?(
               html,
               ~s/form[phx-submit="save-country-rule"] input[name="country_rule\[country_code\]"]/
             )

      assert submit_button(html, ~s/form[phx-submit="save-country-rule"]/)
    end

    test "submitting a valid country saves it", %{conn: conn, site: site, user: user} do
      lv = get_liveview(conn, site)

      lv
      |> element("form")
      |> render_submit(%{
        "country_rule[country_code]" => "EE"
      })

      html = render(lv)

      assert html =~ "Estonia"

      added_by = "#{user.name} <#{user.email}>"

      assert [%{id: id, country_code: "EE", added_by: ^added_by}] =
               Shields.list_country_rules(site)

      tooltip = text_of_attr(html, "#country-#{id}", "title")
      assert tooltip =~ "Added at #{Date.utc_today()}"
      assert tooltip =~ "by #{added_by}"
    end

    test "clicking Remove deletes the rule", %{conn: conn, site: site} do
      {:ok, _} =
        Shields.add_country_rule(site, %{"country_code" => "EE"})

      lv = get_liveview(conn, site)

      html = render(lv)
      assert text_of_element(html, "table tbody td") =~ "Estonia"

      lv |> element(~s/button[phx-click="remove-country-rule"]/) |> render_click()

      html = render(lv)
      refute text_of_element(html, "table tbody td") =~ "Estonia"

      assert Shields.count_country_rules(site) == 0
    end

    defp get_liveview(conn, site) do
      conn = assign(conn, :live_module, PlausibleWeb.Live.Shields)
      {:ok, lv, _html} = live(conn, "/#{site.domain}/settings/shields/countries")

      lv
    end
  end
end
