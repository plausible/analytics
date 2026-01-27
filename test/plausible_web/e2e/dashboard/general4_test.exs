defmodule PlausibleWeb.E2E.Dashboard.General4Test do
  use ExUnit.Case, async: true
  use Wallaby.Feature

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

  feature "dashboard renders", %{session: session, domain: domain} do
    session
    |> visit("/#{domain}")
    |> assert_has(Query.css("button[title]", text: domain))
  end

  feature "filter is applied", %{session: session, domain: domain} do
    modal_url =
      session
      |> visit("/#{domain}")
      |> refute_has(Query.link("Page"))
      |> click(Query.button("Filter"))
      |> assert_has(Query.link("Page", count: 1))
      |> click(Query.link("Page"))
      |> current_url()

    assert modal_url == url(domain, "/filter/page")

    post_filter_url =
      session
      |> assert_has(Query.css("h1", text: "Filter by Page"))
      |> assert_has(Query.css("button[disabled]", text: "Apply filter", count: 1))
      |> click(Query.text_field("Select a Page"))
      |> assert_has(Query.css("button[disabled]", text: "Apply filter", count: 1))
      |> assert_has(Query.css("li", text: "/page1"))
      |> assert_has(Query.css("li", text: "/page2"))
      |> assert_has(Query.css("li", text: "/page3"))
      |> assert_has(Query.css("li", text: "/other"))
      |> fill_in(Query.text_field("Select a Page"), with: "pag")
      |> assert_has(Query.css("li", text: "/page1"))
      |> assert_has(Query.css("li", text: "/page2"))
      |> assert_has(Query.css("li", text: "/page3"))
      |> refute_has(Query.css("li", text: "/other"))
      |> click(Query.css("li", text: "/page1"))
      |> assert_has(Query.css("button:not([disabled])", text: "Apply filter", count: 1))
      |> click(Query.button("Apply filter"))
      |> current_url()

    assert post_filter_url == url(domain, "?f=is,page,/page1")

    session
    |> assert_has(Query.link("Edit filter: Page is /page1"))
  end

  feature "tab selection user preferences are preserved across reloads", %{
    session: session,
    domain: domain
  } do
    session
    |> visit("/#{domain}")
    |> click(Query.button("Entry pages"))

    session
    |> visit("/#{domain}")
    |> execute_script(
      "return localStorage.getItem('pageTab__' + arguments[0])",
      [domain],
      fn result ->
        assert result == "entry-pages"
      end
    )
    |> click(Query.button("Exit pages"))

    session
    |> visit("/#{domain}")
    |> execute_script(
      "return localStorage.getItem('pageTab__' + arguments[0])",
      [domain],
      fn result ->
        assert result == "exit-pages"
      end
    )
  end

  feature "back navigation closes the modal", %{session: session, domain: domain} do
    modal_url =
      session
      |> visit("/#{domain}")
      |> click(Query.button("Filter"))
      |> click(Query.link("Page"))
      |> current_url()

    assert modal_url == url(domain, "/filter/page")

    closed_modal_url =
      session
      |> execute_script("window.history.back()")
      |> current_url()

    assert closed_modal_url == url(domain)
  end

  feature "opens for logged in user", %{session: session} do
    user = new_user(password: "VeryStrongVerySecret")
    site = new_site(owner: user)
    populate_stats(site, [build(:pageview, timestamp: hours_ago(48))])

    session
    |> log_in(user)
    |> visit("/#{site.domain}")
    |> assert_has(Query.css("button[title]", text: site.domain))
  end

  def log_in(session, user, password \\ nil) do
    session
    |> visit("/login")
    |> fill_in(Query.text_field("email"), with: user.email)
    |> fill_in(Query.text_field("password"), with: password || user.password)
    |> click(Query.button("Log in"))

    assert {:ok, session} =
             retry(fn ->
               if current_path(session) == "/sites" do
                 {:ok, assert_has(session, Query.css("h2", text: "My personal sites"))}
               else
                 {:error, :sites_list_not_reached_on_login}
               end
             end)

    session
  end

  def url(domain, path \\ "") do
    PlausibleWeb.Endpoint.url() <> "/#{URI.encode_www_form(domain)}#{path}"
  end

  def hours_ago(hr) do
    NaiveDateTime.utc_now(:second) |> NaiveDateTime.add(-hr, :hour)
  end
end
