defmodule PlausibleWeb.TrackerTest do
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

  def get_script(filename) do
    opts = PlausibleWeb.Tracker.init([])

    conn(:get, "/js/#{filename}")
    |> PlausibleWeb.Tracker.call(opts)
    |> response(200)
  end
end
