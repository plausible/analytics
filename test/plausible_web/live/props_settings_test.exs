defmodule PlausibleWeb.Live.PropsSettingsTest do
  use PlausibleWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  describe "GET /:domain/settings/properties" do
    setup [:create_user, :log_in, :create_site]

    @tag :ee_only
    test "premium feature notice renders", %{conn: conn, site: site, user: user} do
      user
      |> Plausible.Auth.User.end_trial()
      |> Plausible.Repo.update!()
      |> Plausible.Teams.sync_team()

      conn = get(conn, "/#{site.domain}/settings/properties")
      resp = conn |> html_response(200) |> text()

      assert resp =~ "please upgrade your subscription"
    end

    test "lists props for the site and renders links", %{conn: conn, site: site} do
      {:ok, site} = Plausible.Props.allow(site, ["amount", "logged_in", "is_customer"])
      conn = get(conn, "/#{site.domain}/settings/properties")

      resp = html_response(conn, 200)
      assert resp =~ "Attach Custom Properties"

      assert element_exists?(
               resp,
               ~s|a[href="https://plausible.io/docs/custom-props/introduction"]|
             )

      assert resp =~ "amount"
      assert resp =~ "logged_in"
      assert resp =~ "is_customer"
      refute resp =~ "please upgrade your subscription"
    end

    test "lists props with disallow actions", %{conn: conn, site: site} do
      {:ok, site} = Plausible.Props.allow(site, ["amount", "logged_in", "is_customer"])
      conn = get(conn, "/#{site.domain}/settings/properties")
      resp = html_response(conn, 200)

      for p <- site.allowed_event_props do
        assert element_exists?(
                 resp,
                 ~s/button[phx-click="disallow-prop"][phx-value-prop=#{p}]#disallow-prop-#{p}/
               )
      end
    end

    test "if no props are allowed, a proper info is displayed", %{conn: conn, site: site} do
      conn = get(conn, "/#{site.domain}/settings/properties")
      resp = html_response(conn, 200)
      assert resp =~ "No properties configured for this site"
    end

    test "if props are enabled, no info about missing props is displayed", %{
      conn: conn,
      site: site
    } do
      {:ok, site} = Plausible.Props.allow(site, ["amount", "logged_in", "is_customer"])
      conn = get(conn, "/#{site.domain}/settings/properties")
      resp = html_response(conn, 200)
      refute resp =~ "No properties configured for this site"
    end

    test "add property button is rendered", %{conn: conn, site: site} do
      conn = get(conn, "/#{site.domain}/settings/properties")
      resp = html_response(conn, 200)
      assert element_exists?(resp, ~s/button[phx-click="add-prop"]/)
    end

    test "search props input is rendered", %{conn: conn, site: site} do
      conn = get(conn, "/#{site.domain}/settings/properties")
      resp = html_response(conn, 200)
      assert element_exists?(resp, ~s/input[type="text"]#filter-text/)
      assert element_exists?(resp, ~s/form[phx-change="filter"]#filter-form/)
    end
  end

  # validating input
  # clicking suggestions fills out input
  # adding props
  # error when reached props limit
  # clearserror when fixed input
  # removal
  # removal shows confirmation
  # allow existing props: shows/hides
  # after adding all suggestions no allow existing props

  describe "PropsSettings live view" do
    setup [:create_user, :log_in, :create_site]

    test "allows prop removal", %{conn: conn, site: site} do
      {:ok, site} = Plausible.Props.allow(site, ["amount", "logged_in"])
      {lv, html} = get_liveview(conn, site, with_html?: true)

      assert html =~ "amount"
      assert html =~ "logged_in"

      html = lv |> element(~s/button#disallow-prop-amount/) |> render_click()

      refute html =~ "amount"
      assert html =~ "logged_in"

      html = get(conn, "/#{site.domain}/settings/properties") |> html_response(200)

      refute html =~ "amount"
      assert html =~ "logged_in"
    end

    test "allows props filtering / search", %{conn: conn, site: site} do
      {:ok, site} = Plausible.Props.allow(site, ["amount", "logged_in", "is_customer"])
      {lv, html} = get_liveview(conn, site, with_html?: true)

      assert html =~ to_string("amount")
      assert html =~ to_string("logged_in")
      assert html =~ to_string("is_customer")

      html = type_into_search(lv, "is_customer")

      refute html =~ to_string("amount")
      refute html =~ to_string("logged_in")
      assert html =~ to_string("is_customer")
    end

    test "allows resetting filter text via backspace icon", %{conn: conn, site: site} do
      {:ok, site} = Plausible.Props.allow(site, ["amount", "logged_in", "is_customer"])
      {lv, html} = get_liveview(conn, site, with_html?: true)

      refute element_exists?(html, ~s/svg[phx-click="reset-filter-text"]#reset-filter/)

      html = type_into_search(lv, to_string("is_customer"))

      assert element_exists?(html, ~s/svg[phx-click="reset-filter-text"]#reset-filter/)

      html = lv |> element(~s/svg#reset-filter/) |> render_click()

      assert html =~ to_string("is_customer")
      assert html =~ to_string("amount")
      assert html =~ to_string("logged_in")
    end

    test "allows resetting filter text via no match link", %{conn: conn, site: site} do
      lv = get_liveview(conn, site)
      html = type_into_search(lv, "Definitely this is not going to render any matches")

      assert html =~ "No properties found for this site. Please refine or"
      assert html =~ "reset your search"

      assert element_exists?(html, ~s/a[phx-click="reset-filter-text"]#reset-filter-hint/)
      html = lv |> element(~s/a#reset-filter-hint/) |> render_click()

      refute html =~ "No properties found for this site. Please refine or"
    end

    test "clicking Add Property button renders the form view", %{conn: conn, site: site} do
      lv = get_liveview(conn, site)
      html = lv |> element(~s/button[phx-click="add-prop"]/) |> render_click()

      assert html =~ "Add Property for #{site.domain}"

      assert element_exists?(
               html,
               ~s/div#props-form form[phx-submit="allow-prop"][phx-click-away="cancel-allow-prop"]/
             )
    end
  end

  defp get_liveview(conn, site, opts \\ []) do
    conn = assign(conn, :live_module, PlausibleWeb.Live.PropsSettings)
    {:ok, lv, html} = live(conn, "/#{site.domain}/settings/properties")

    if Keyword.get(opts, :with_html?) do
      {lv, html}
    else
      lv
    end
  end

  defp type_into_search(lv, text) do
    lv
    |> element("form#filter-form")
    |> render_change(%{
      "_target" => ["filter-text"],
      "filter-text" => "#{text}"
    })
  end
end
