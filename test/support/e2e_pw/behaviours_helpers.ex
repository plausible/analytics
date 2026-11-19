defmodule PlausibleE2E.BehavioursHelpers do
  @moduledoc "Helpers shared by the ported behaviours spec modules."

  alias Playwright.{Expect, Locator, Page, Test}
  require Test
  import PlausibleE2E.Utils

  def report(page), do: Page.get_by_test_id(page, "report-behaviours")

  def last_30min_pill, do: "last 30min"

  def scroll_to_end(report) do
    report |> Locator.get_by_test_id("report-end") |> Locator.scroll_into_view_if_needed!()
  end

  def expect_active(locator), do: Expect.to_have_attribute!(locator, "data-active", "true")

  def close_modal(page), do: page |> close_modal_button() |> Locator.click!()

  def expect_modal_heading(page, name),
    do: page |> modal() |> Locator.get_by_role(:heading, name: name) |> Expect.to_be_visible!()

  @doc """
  One special goal of the 'special goals' test: click the goal row, check the special report
  and its modal, as the two `test.step`s of the spec.
  """
  def special_goal(page, report, spec) do
    %{
      goal: goal,
      tab: tab,
      modal: modal_heading,
      key: key,
      values: values,
      modal_rows: modal_rows
    } =
      spec

    Test.step "#{goal} goal is treated as a special goal" do
      row_link(report, goal) |> Locator.click!()

      report |> tab_button(tab) |> expect_active()

      expect_headers(report, [key, "Visitors", "Events", "CR"])

      for value <- values, do: expect_metric_values(report, value, ["1", "1", "50%"])
    end

    Test.step "#{goal} special-goal modal" do
      report |> details_link() |> Locator.click!()

      expect_modal_heading(page, modal_heading)

      expect_headers(modal(page), [key, ~r/Visitors/, ~r/Events/, ~r/CR/])

      expect_rows(modal(page), modal_rows)

      expect_metric_values(modal(page), hd(values), ["1", "1", "50%"])

      close_modal(page)
    end
  end
end
