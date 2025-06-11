defmodule PlausibleWeb.Live.PluginsAPISettingsTest do
  use PlausibleWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  alias Plausible.Plugins.API.Tokens

  describe "GET /:domain/settings/integrations" do
    setup [:create_user, :log_in, :create_site]

    test "does not display the Plugins API section by default", %{conn: conn, site: site} do
      conn = get(conn, "/#{site.domain}/settings/integrations")
      resp = html_response(conn, 200)

      refute resp =~ "Plugin Tokens"
    end

    test "does display the Plugins API section on ?new_token=....", %{
      conn: conn,
      site: site
    } do
      conn = get(conn, "/#{site.domain}/settings/integrations?new_token=test")
      resp = html_response(conn, 200)

      assert resp =~ "Plugin Tokens"
    end

    test "does display the Plugins API section when there are tokens already created", %{
      conn: conn,
      site: site
    } do
      {:ok, _, _} = Tokens.create(site, "test")
      conn = get(conn, "/#{site.domain}/settings/integrations")
      resp = html_response(conn, 200)

      assert resp =~ "Plugin Tokens"
    end

    test "lists tokens with revoke actions", %{conn: conn, site: site} do
      {:ok, t1, _} = Tokens.create(site, "test-token-1")
      {:ok, t2, _} = Tokens.create(site, "test-token-2")
      {:ok, _, _} = Tokens.create(build(:site), "test-token-3")

      conn = get(conn, "/#{site.domain}/settings/integrations")
      resp = html_response(conn, 200)

      assert resp =~ "test-token-1"
      assert resp =~ "test-token-2"

      assert resp =~ "Last used"
      assert resp =~ "Not yet"

      assert resp =~ "**********" <> t1.hint
      assert resp =~ "**********" <> t2.hint
      refute resp =~ "test-token-3"

      assert element_exists?(
               resp,
               ~s/button[phx-click="revoke-token"][phx-value-token-id=#{t1.id}]#revoke-token-#{t1.id}/
             )

      assert element_exists?(
               resp,
               ~s/button[phx-click="revoke-token"][phx-value-token-id=#{t2.id}]#revoke-token-#{t2.id}/
             )
    end

    test "create token button is rendered", %{conn: conn, site: site} do
      conn = get(conn, "/#{site.domain}/settings/integrations?new_token=WordPress")
      resp = html_response(conn, 200)

      assert element_exists?(resp, ~s/button[phx-click="create-token"]/)
    end
  end

  describe "Plugins.API.Settings live view" do
    setup [:create_user, :log_in, :create_site]

    test "create token when invoked via URL", %{conn: conn, site: site} do
      {lv, html} =
        get_liveview(conn, site, with_html?: true, query_params: "?new_token=WordPress")

      assert element_exists?(html, "#token-form")
      assert text_of_element(html, "label[for=token_description]") == "Description"
      assert element_exists?(html, "input[value=WordPress]#token_description")

      assert element_exists?(
               html,
               ~s/div#token-form form[phx-submit="generate-token"]/
             )

      html =
        lv
        |> find_live_child("token-form")
        |> element("form")
        |> render_submit()

      assert text_of_element(html, "label[for=token-clipboard]") == "Plugin Token"
      assert element_exists?(html, "input#token-clipboard")
      assert element_exists?(html, ~s/button[phx-click="close-token-modal"]/)

      assert Tokens.any?(site)
    end

    test "adds token and shows it", %{conn: conn, site: site} do
      refute Tokens.any?(site)

      lv = get_liveview(conn, site, query_params: "?new_token=WordPress")

      lv
      |> find_live_child("token-form")
      |> element("form")
      |> render_submit()

      assert Tokens.any?(site)

      html = render(lv)
      assert text_of_element(html, "label[for=token-clipboard]") == "Plugin Token"
      assert element_exists?(html, "input#token-clipboard")
      assert text_of_element(html, "span.token-description") == "WordPress"
    end

    test "fails to add token with no description", %{conn: conn, site: site} do
      {:ok, _, _} = Tokens.create(site, "test")

      lv = get_liveview(conn, site)

      lv |> render_click("create-token")

      lv
      |> find_live_child("token-form")
      |> element("form")
      |> render_submit()

      assert [_] = Tokens.list(site)
    end
  end

  defp get_liveview(conn, site, opts \\ []) do
    query_params = Keyword.get(opts, :query_params, "")
    conn = assign(conn, :live_module, PlausibleWeb.Live.Plugins.API.Settings)
    {:ok, lv, html} = live(conn, "/#{site.domain}/settings/integrations#{query_params}")

    if Keyword.get(opts, :with_html?) do
      {lv, html}
    else
      lv
    end
  end
end
