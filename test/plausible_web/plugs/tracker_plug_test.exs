defmodule PlausibleWeb.TrackerPlugTest do
  @moduledoc """
  This test module uses auto-generated JavaScript tracker files in priv/tracker/js.

  To speed up running Elixir tests locally, the tracker files are not automatically generated
  with every `mix test` command. That means, you have to manually run the below command
  once before executing `mix test`. This is to make sure all tracker files are in place and up to date.

  ```
  npm run deploy --prefix tracker
  ```

  If you're making changes in the tracker template files (`src/plausible.js`, `compile.js`),
  do regenerate the files before running tests, so they're up to date.
  """
  use PlausibleWeb.ConnCase, async: true
  use Plug.Test
  use Plausible.Teams.Test

  describe "plausible-main.js" do
    @example_config %{
      "404" => true,
      "hash" => true,
      "file-downloads" => false,
      "outbound-links" => false,
      "pageview-props" => false,
      "tagged-events" => true,
      "revenue" => false
    }

    test "returns the script for an existing site", %{conn: conn} do
      site =
        new_site()
        |> Plausible.Sites.update_installation_meta!(%{script_config: @example_config})

      response = get(conn, "/js/s-#{site.installation_meta.id}.js") |> response(200)

      assert String.contains?(response, "!function(){var")
      assert String.contains?(response, "domain:\"#{site.domain}\"")
      assert String.contains?(response, "hash:!0")
      assert String.contains?(response, "taggedEvents:!0")
      assert not String.contains?(response, "outboundLinks:!0")
    end

    # window.plausible is a substring checked for by the wordpress plugin to avoid 'optimization' by other wordpress plugins
    test "script contains window.plausible", %{conn: conn} do
      site =
        new_site()
        |> Plausible.Sites.update_installation_meta!(%{script_config: @example_config})

      response = get(conn, "/js/s-#{site.installation_meta.id}.js") |> response(200)

      assert String.contains?(response, "window.plausible")
    end

    test "returns 404 for unknown site", %{conn: conn} do
      conn
      |> get("/js/s-a14125a2-000-000-0000-000000000000.js")
      |> response(404)
    end
  end

  describe "legacy variants" do
    test "returns legacy script p.js" do
      assert String.contains?(get_script("p.js"), "; samesite=strict; path=/")
    end

    test "returns plausible script with every alias" do
      plausible_js_response = get_script("plausible.js")

      assert plausible_js_response == get_script("script.js")
      assert plausible_js_response == get_script("analytics.js")
    end

    test "returns the right script extensions no matter the order" do
      response = get_script("plausible.compat.file-downloads.hash.outbound-links.js")

      assert String.contains?(response, "getElementById(\"plausible\")")
      assert String.contains?(response, "file-types")
      assert String.contains?(response, "hashchange")
      assert String.contains?(response, "Outbound Link: Click")

      assert !String.contains?(response, "data-exclude")
      # local extension disabled
      assert String.contains?(response, "/^localhost$|^127(\\.[0-9]+)")

      assert response == get_script("plausible.outbound-links.file-downloads.compat.hash.js")
    end

    test "pageleave extension" do
      # Some customers who have participated in the private preview of the
      # scroll depth feature, have updated their tracking scripts to
      # `script.pageleave.js` per our request. With the public release of
      # scroll depth, this functionality is included in the default script,
      # but we must continue to serve `script.pageleave.js` for as long as
      # those customers are still using it.
      assert get_script("script.pageleave.js") == get_script("script.js")
      assert get_script("script.manual.pageleave.js") == get_script("script.manual.js")
    end

    for variant <- [
          "plausible.js",
          "script.manual.pageview-props.tagged-events.pageleave.js",
          "script.compat.local.exclusions.js",
          "script.hash.revenue.file-downloads.pageview-props.js"
        ] do
      test "variant #{variant} is available" do
        script = get_script(unquote(variant))
        assert String.starts_with?(script, "!function(){var")
        assert String.length(script) > 200

        assert String.contains?(script, "window.plausible")
      end
    end
  end

  def get_script(filename) do
    opts = PlausibleWeb.TrackerPlug.init([])

    conn(:get, "/js/#{filename}")
    |> PlausibleWeb.TrackerPlug.call(opts)
    |> response(200)
  end
end
