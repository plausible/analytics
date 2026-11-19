defmodule PlausibleE2E.Dashboard.GeneralTest do
  use PlausibleE2E.Case, async: true

  test "dashboard renders for logged in user", %{page: page, request: request} do
    %{domain: domain} = setup_site(page: page, request: request)
    populate_stats(request: request, domain: domain, events: [%{name: "pageview"}])

    Page.goto!(page, "/" <> domain, wait_until: :commit)

    Expect.to_have_title!(page, ~r/Plausible/)

    Expect.to_be_visible!(Page.get_by_role(page, :button, name: domain))
  end

  test "dashboard renders for anonymous viewer", %{page: page, request: request} do
    %{domain: domain} = setup_site(page: page, request: request)
    make_site_public(page: page, domain: domain)
    populate_stats(request: request, domain: domain, events: [%{name: "pageview"}])
    logout(page)

    Page.goto!(page, "/" <> domain, wait_until: :commit)

    Expect.to_have_title!(page, ~r/Plausible/)

    Expect.to_contain_text!(Page.get_by_test_id(page, "site-switcher-static"), domain)
  end

  test "dashboard renders via shared link", %{page: page, request: request} do
    %{domain: domain} = setup_site(page: page, request: request)
    populate_stats(request: request, domain: domain, events: [%{name: "pageview"}])
    link = create_shared_link(page: page, domain: domain, name: "public_link")

    password_link =
      create_shared_link(page: page, domain: domain, name: "password_link", password: "secret")

    logout(page)

    Test.step "public link" do
      Page.goto!(page, link, wait_until: :commit)

      Expect.to_contain_text!(Page.get_by_test_id(page, "site-switcher-static"), domain)

      Expect.to_have_text!(Page.locator(page, "#visitors"), "1")
    end

    Test.step "password protected link" do
      Page.goto!(page, password_link, wait_until: :commit)

      Page.locator(page, "input#password") |> Locator.fill!("secret")

      Page.get_by_role(page, :button, name: "Continue") |> Locator.click!()

      Expect.to_contain_text!(Page.get_by_test_id(page, "site-switcher-static"), domain)

      Expect.to_have_text!(Page.locator(page, "#visitors"), "1")
    end
  end

  test "site switcher is not shown when viewing without being logged in", %{
    page: page,
    request: request
  } do
    %{domain: domain} = setup_site(page: page, request: request)
    make_site_public(page: page, domain: domain)
    populate_stats(request: request, domain: domain, events: [%{name: "pageview"}])
    logout(page)

    Page.goto!(page, "/" <> domain, wait_until: :commit)

    site_switcher_static = Page.get_by_test_id(page, "site-switcher-static")
    Expect.to_contain_text!(site_switcher_static, domain)
    site_switcher_static |> Expect.not_() |> Expect.to_have_role!(:button)

    Locator.click!(site_switcher_static)
    Expect.to_be_hidden!(Page.get_by_test_id(page, "sitemenu"))
  end

  test "dashboard renders with imported data", %{page: page, request: request} do
    %{domain: domain} = setup_site(page: page, request: request)

    populate_stats(
      request: request,
      domain: domain,
      events: [
        %{name: "pageview"},
        %{type: "imported_visitors", visitors: 3, visits: 4, pageviews: 6, bounces: 1}
      ]
    )

    Page.goto!(page, "/" <> domain, wait_until: :commit)

    Test.step "with imported data included" do
      Expect.to_have_text!(Page.locator(page, "#visitors"), "4")
      Expect.to_have_text!(Page.locator(page, "#visits"), "5")
      Expect.to_have_text!(Page.locator(page, "#pageviews"), "7")
      Expect.to_have_text!(Page.locator(page, "#bounce_rate"), "40%")
    end

    Test.step "with imported data excluded" do
      Page.get_by_test_id(page, "dashboard-options-menu") |> Locator.click!()
      Page.get_by_test_id(page, "import-switch") |> Locator.click!()

      Expect.to_have_url!(page, ~r/with_imported=false/)

      Expect.to_have_text!(Page.locator(page, "#visitors"), "1")
      Expect.to_have_text!(Page.locator(page, "#visits"), "1")
      Expect.to_have_text!(Page.locator(page, "#pageviews"), "1")
      Expect.to_have_text!(Page.locator(page, "#bounce_rate"), "100%")
    end
  end

  test "tab selection user preferences are preserved across reloads", %{
    page: page,
    request: request
  } do
    %{domain: domain} = setup_site(page: page, request: request)
    populate_stats(request: request, domain: domain, events: [%{name: "pageview"}])

    Page.goto!(page, "/" <> domain, wait_until: :commit)

    Page.get_by_role(page, :button, name: "Entry pages") |> Locator.click!()

    Page.goto!(page, "/" <> domain, wait_until: :commit)

    current_tab =
      Page.evaluate!(page, "(domain) => localStorage.getItem('pageTab__' + domain)", domain)

    assert current_tab == "entryPages"

    Page.get_by_role(page, :button, name: "Exit pages") |> Locator.click!()

    Page.goto!(page, "/" <> domain, wait_until: :commit)

    current_tab =
      Page.evaluate!(page, "(domain) => localStorage.getItem('pageTab__' + domain)", domain)

    assert current_tab == "exitPages"
  end

  test "back navigation removes an applied filter", %{page: page, request: request} do
    base_url = Test.info().use[:base_url]
    %{domain: domain} = setup_site(page: page, request: request)

    populate_stats(
      request: request,
      domain: domain,
      events: [%{name: "pageview", pathname: "/page1"}]
    )

    Page.goto!(page, "/" <> domain, wait_until: :commit)

    Page.get_by_role(page, :button, name: "Filter") |> Locator.click!()

    open_filter_submenu_item(page, "Page", "Page")
    pick_filter_value(page, value: "/page1")
    close_filter_editor(page)

    Expect.to_have_url!(page, ~r"f=is,page,/page1")

    Page.go_back!(page)

    Expect.to_have_url!(page, base_url <> "/" <> domain)
  end
end
