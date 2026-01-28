defmodule PlausibleWeb.E2E.Dashboard.General10Test do
  use PhoenixTest.Playwright.Case, async: true

  use Plausible.Repo
  use Plausible.TestUtils
  use Plausible
  use Plausible.Teams.Test

  import Plausible.DataCase
  import Plausible.Factory

  @moduletag :e2e

  setup do
    site = new_site(public: true)

    populate_stats(site, [
      build(:pageview, pathname: "/page1", timestamp: hours_ago(48)),
      build(:pageview, pathname: "/page2", timestamp: hours_ago(48)),
      build(:pageview, pathname: "/page3", timestamp: hours_ago(48)),
      build(:pageview, pathname: "/other", timestamp: hours_ago(48))
    ])

    {:ok, domain: site.domain}
  end

  test "dashboard renders", %{conn: conn, domain: domain} do
    conn
    |> visit("/#{domain}")
    |> assert_has("button[title]", text: domain)
  end

  test "filter is applied", %{conn: conn, domain: domain} do
    conn
    |> visit("/#{domain}")
    |> refute_has("a[href]", text: "Page")
    |> click_button("Filter")
    |> assert_has("a[href]", text: "Page", count: 1)
    |> click_link("Page")
    |> assert_url(url(domain, "/filter/page"))
    |> assert_has("h1", text: "Filter by Page")
    |> assert_has("button[disabled]", text: "Apply filter", count: 1)
    |> click("input[placeholder='Select a Page']")
    |> assert_has("button[disabled]", text: "Apply filter", count: 1)
    |> assert_has("li", text: "/page1")
    |> assert_has("li", text: "/page2")
    |> assert_has("li", text: "/page3")
    |> assert_has("li", text: "/other")
    |> type("input[placeholder='Select a Page']", "pag")
    |> assert_has("li", text: "/page1")
    |> assert_has("li", text: "/page2")
    |> assert_has("li", text: "/page3")
    |> refute_has("li", text: "/other")
    |> click("li", "/page1")
    |> assert_has("button:not([disabled])", text: "Apply filter", count: 1)
    |> click_button("Apply filter")
    |> assert_url(url(domain, "?f=is,page,/page1"))
    |> assert_has("a[title='Edit filter: Page is /page1']")
  end

  test "tab selection user preferences are preserved across reloads", %{
    conn: conn,
    domain: domain
  } do
    conn
    |> visit("/#{domain}")
    |> click_button("Entry pages")
    |> visit("/#{domain}")
    |> assert_local_storage("pageTab__#{domain}", "entry-pages")
    |> click_button("Exit pages")
    |> visit("/#{domain}")
    |> assert_local_storage("pageTab__#{domain}", "exit-pages")
  end

  test "back navigation closes the modal", %{conn: conn, domain: domain} do
    conn
    |> visit("/#{domain}")
    |> click_button("Filter")
    |> click_link("Page")
    |> assert_url(url(domain, "/filter/page"))
    |> unwrap(
      &PlaywrightEx.Frame.evaluate(&1.frame_id,
        expression: "window.history.back()",
        timeout: 1000
      )
    )
    |> assert_url(url(domain))
  end

  test "opens for logged in user", %{conn: conn} do
    user = new_user(password: "VeryStrongVerySecret")
    site = new_site(owner: user)
    populate_stats(site, [build(:pageview, timestamp: hours_ago(48))])

    conn
    |> log_in(user)
    |> visit("/#{site.domain}")
    |> assert_has("button[title]", text: site.domain)
  end

  def log_in(conn, user, password \\ nil) do
    conn
    |> visit("/login")
    |> type("input[name=email]", user.email)
    |> type("input[name=password]", password || user.password)
    |> click_button("Log in")
  end

  def url(domain, path \\ "") do
    PlausibleWeb.Endpoint.url() <> "/#{URI.encode_www_form(domain)}#{path}"
  end

  def hours_ago(hr) do
    NaiveDateTime.utc_now(:second) |> NaiveDateTime.add(-hr, :hour)
  end

  def assert_url(conn, url) do
    {:ok, current_url} =
      PlaywrightEx.Frame.evaluate(conn.frame_id,
        expression: "document.location.href",
        timeout: 1000
      )

    assert current_url == url

    conn
  end

  def assert_local_storage(conn, key, value) do
    {:ok, current_value} =
      PlaywrightEx.Frame.evaluate(conn.frame_id,
        expression: "localStorage.getItem('#{key}')",
        timeout: 1000
      )

    assert current_value == value

    conn
  end
end
