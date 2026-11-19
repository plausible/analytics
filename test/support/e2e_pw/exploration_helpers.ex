defmodule PlausibleE2E.ExplorationHelpers do
  @moduledoc "Helpers shared by the exploration specs (the consts at the top of exploration.spec.ts)."

  alias Playwright.{Expect, Locator, Page}
  import PlausibleE2E.Fixtures, only: [setup_site: 1, populate_stats: 1]

  def report(page), do: Page.get_by_test_id(page, "report-behaviours")

  def column(report, i), do: Locator.get_by_test_id(report, "exploration-column-#{i}")

  def labels(col),
    do: col |> Locator.get_by_test_id("exploration-row") |> Locator.get_by_test_id("metric-label")

  def values(col),
    do: col |> Locator.get_by_test_id("exploration-row") |> Locator.get_by_test_id("metric-value")

  def button(col, name), do: Locator.get_by_role(col, :button, name: name)

  def row(col, i), do: col |> Locator.get_by_test_id("exploration-row") |> Locator.nth(i)

  def expect_step(col, name, step),
    do: col |> button(name) |> Expect.to_have_attribute!("data-exploration-step", step)

  def expect_no_step(col, name, step \\ nil) do
    col
    |> button(name)
    |> Expect.not_()
    |> Expect.to_have_attribute!("data-exploration-step", step)
  end

  @doc "Sets up a site with `events`, opens the dashboard and the Explore tab. Returns `%{report:, domain:}`."
  def open_exploration(page, request, events) do
    %{domain: domain} = setup_site(page: page, request: request)
    populate_stats(request: request, domain: domain, events: events)
    open_exploration_for(page, domain)
  end

  def open_exploration_for(page, domain) do
    report = report(page)
    Page.goto!(page, "/" <> domain, wait_until: :commit)

    report
    |> Locator.get_by_test_id("tab-button")
    |> Locator.filter(has_text: "Explore")
    |> Locator.click!()

    report |> Locator.get_by_test_id("report-end") |> Locator.scroll_into_view_if_needed!()

    Expect.to_have_text!(
      Locator.get_by_test_id(report, "exploration-title"),
      "Explore user journeys"
    )

    %{report: report, domain: domain}
  end

  def ev(user_id, path, ago, extra \\ %{}) do
    Map.merge(%{user_id: user_id, name: "pageview", pathname: path, timestamp: ago}, extra)
  end

  def mins(n), do: %{minutesAgo: n}
end
