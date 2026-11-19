defmodule PlausibleE2E.FilteringHelpers do
  @moduledoc "Shared bits of the filtering specs."

  alias Playwright.{Expect, Locator, Page}

  @doc "`page.getByRole('button', { name: 'Remove filter: <pill>' }).click()`"
  def remove_filter(page, pill_name) do
    page |> Page.get_by_role(:button, name: "Remove filter: #{pill_name}") |> Locator.click!()
  end

  def expect_url(page, regex), do: Expect.to_have_url!(page, regex)
  def expect_no_url(page, regex), do: Expect.not_to_have_url!(page, regex)
end
