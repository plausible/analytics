defmodule PlausibleE2E.Utils do
  @moduledoc "Port of e2e/tests/test-utils.ts."

  import ExUnit.Assertions

  alias Playwright.{Expect, Locator, Page}

  @doc "`currentTime()`: now in UTC, truncated to seconds."
  def current_time, do: DateTime.utc_now() |> DateTime.truncate(:second)

  @doc "`timeToISO(ts)`: ISO_LOCAL_DATE_TIME."
  def time_to_iso(ts), do: ts |> DateTime.to_naive() |> NaiveDateTime.to_iso8601()

  def expect_live_view_connected(page) do
    Expect.poll!(fn -> Locator.count!(Page.locator(page, ".phx-connected")) end, &assert(&1 > 0))
  end

  defp visible_flash(page),
    do: page |> Page.get_by_test_id("live-flash") |> Locator.filter(visible: true)

  def has_flash_message(page, message \\ nil) do
    flash = visible_flash(page)
    flash = if message, do: Locator.filter(flash, has_text: message), else: flash
    Expect.to_be_visible!(flash)
  end

  def has_no_flash_message(page), do: Expect.to_have_count!(visible_flash(page), 0)

  def close_flash_message(page) do
    visible_flash(page) |> Locator.get_by_role(:button) |> Locator.click!()
    has_no_flash_message(page)
  end

  def random_id,
    do: :rand.uniform(1_000_000_000_000_000) |> Integer.to_string(16) |> String.downcase()

  # `Page | Locator` in the TS, so these dispatch on the struct.
  defp get_by_test_id(%Locator{} = locator, id), do: Locator.get_by_test_id(locator, id)
  defp get_by_test_id(page, id), do: Page.get_by_test_id(page, id)

  def tab_button(page_or_locator, label),
    do: page_or_locator |> get_by_test_id("tab-button") |> Locator.filter(has_text: label)

  def tab_button_with_dropdown(page_or_locator, label),
    do:
      page_or_locator
      |> get_by_test_id("tab-button-with-dropdown")
      |> Locator.filter(has_text: label)

  def header(report, label) do
    report
    |> Locator.get_by_test_id("report-header")
    |> Locator.filter(has_text: label)
    |> Locator.get_by_role(:button)
  end

  def expect_headers(report, headers),
    do: report |> Locator.get_by_test_id("report-header") |> Expect.to_have_text!(headers)

  def expect_rows(report, labels) do
    report
    |> Locator.get_by_test_id("report-row")
    |> Locator.get_by_test_id("dimension-value")
    |> Expect.to_have_text!(labels)
  end

  def row_link(report, label) do
    report
    |> Locator.get_by_test_id("report-row")
    |> Locator.filter(has_text: label)
    |> Locator.get_by_test_id("dimension-value")
  end

  def expect_metric_values(report, label, values) do
    report
    |> Locator.get_by_test_id("report-row")
    |> Locator.filter(has_text: label)
    |> Locator.get_by_test_id("metric-value")
    |> Expect.to_have_text!(values)
  end

  def dropdown(report), do: Locator.get_by_test_id(report, "dropdown-items")

  # Needed before opening dropdown again right after it closes (usually, when picking an item).
  # There's a leave transition for the dropdown and interacting with the dropdown opener
  # during the transition may mean that the dropdown doesn't actually open.
  def expect_dropdown_closed(report), do: Expect.to_have_count!(dropdown(report), 0)

  def search_input(report), do: Locator.get_by_test_id(report, "search-input")

  def modal(page), do: Page.locator(page, ".modal")

  def details_link(report), do: Locator.get_by_role(report, :link, name: "View details")

  def close_modal_button(page), do: Page.get_by_role(page, :button, name: "Close modal")

  def filter_button(page), do: Page.get_by_role(page, :button, name: ~r/^(Filter|Add filter)$/)

  defp filter_menu(page), do: Page.get_by_test_id(page, "filtermenu")

  defp filter_submenu(page), do: Page.get_by_test_id(page, "filtermenu-submenu")

  def filter_item_button(page, label),
    do: filter_menu(page) |> Locator.get_by_role(:button, name: label, exact: true)

  def filter_submenu_item_button(page, label),
    do: filter_submenu(page) |> Locator.get_by_role(:button, name: label, exact: true)

  def filter_submenu_segment_item(page, name),
    do: filter_submenu(page) |> Locator.get_by_role(:link) |> Locator.filter(has_text: name)

  def open_filter_submenu_item(page, row, item) do
    filter_item_button(page, row) |> Locator.click!()
    filter_submenu_item_button(page, item) |> Locator.click!()
  end

  def open_segments_submenu(page), do: filter_item_button(page, "Segment") |> Locator.click!()

  # Waits for the panel to unmount. Reopening the menu during its closing
  # animation leaves the panel unmounted.
  def close_filter_menu(page) do
    filter_button(page) |> Locator.click!()
    Expect.to_be_hidden!(filter_menu(page))
  end

  def open_property_keys(page), do: filter_item_button(page, "Property") |> Locator.click!()

  def property_key_search(page), do: Page.get_by_role(page, :combobox, name: "Properties")

  def property_key_option(page, key) do
    page
    |> Page.get_by_role(:listbox, name: "Properties")
    |> Locator.get_by_role(:option, name: key, exact: true)
  end

  def filter_pill(page, name), do: Page.get_by_role(page, :group, name: name, exact: true)

  def filter_pill_values_button(page, name),
    do: Page.get_by_role(page, :button, name: "Edit filter: #{name}", exact: true)

  def filter_pill_operator_button(page, name),
    do: Page.get_by_role(page, :button, name: "Change operator: #{name}", exact: true)

  def filter_operator_option(page, option) do
    page
    |> Page.get_by_role(:group, name: "Operators")
    |> Locator.get_by_role(:button, name: option, exact: true)
  end

  def filter_value_search(page), do: Page.get_by_role(page, :combobox, name: ~r/^Values/)

  def filter_value_option(page, label) do
    page
    |> Page.get_by_role(:listbox, name: ~r/^Values/)
    |> Locator.get_by_role(:option, name: label, exact: true)
  end

  def pick_filter_value(page, opts) do
    if search = opts[:search], do: filter_value_search(page) |> Locator.fill!(search)
    filter_value_option(page, Keyword.fetch!(opts, :value)) |> Locator.click!()
  end

  def close_filter_editor(page) do
    Playwright.Keyboard.press!(Page.keyboard(page), "Escape")
    Expect.to_be_hidden!(Page.get_by_role(page, :listbox, name: ~r/^Values/))
  end
end
