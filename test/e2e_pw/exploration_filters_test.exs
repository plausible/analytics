defmodule PlausibleE2E.Dashboard.ExplorationFiltersTest do
  use PlausibleE2E.Case, async: true

  import PlausibleE2E.ExplorationHelpers

  test "change filters during a 3-step journey", %{page: page, request: request} do
    %{report: report} =
      open_exploration(page, request, [
        ev(123, "/home", mins(20), %{browser: "Firefox"}),
        ev(123, "/login", mins(19), %{browser: "Firefox"}),
        ev(123, "/dashboard", mins(18), %{browser: "Chrome"}),
        ev(124, "/home", mins(20), %{browser: "Chrome"}),
        ev(124, "/login", mins(19), %{browser: "Chrome"}),
        ev(125, "/other", mins(20), %{browser: "Safari"}),
        ev(125, "/journey", mins(19), %{browser: "Safari"})
      ])

    Expect.to_be_visible!(Locator.get_by_test_id(report, "exploration-direction-forward"))

    first_column = column(report, 0)
    second_column = column(report, 1)
    third_column = column(report, 2)
    fourth_column = column(report, 3)

    devices_link = fn name ->
      page |> Page.get_by_test_id("report-devices") |> Locator.get_by_role(:link, name: name)
    end

    # JS does not await the click
    remove_filter = fn name ->
      page |> Page.get_by_role(:button, name: "Remove filter: " <> name) |> Locator.click!()
    end

    first_column |> button("/home") |> Locator.click!()
    expect_step(first_column, "/home", "0")

    second_column |> button("/login") |> Locator.click!()
    expect_step(second_column, "/login", "1")

    third_column |> button("/dashboard") |> Locator.click!()
    expect_step(third_column, "/dashboard", "2")

    Expect.to_have_text!(fourth_column, ~r/No further steps found/)

    Expect.to_have_text!(labels(first_column), [
      "/home",
      "/login",
      "/dashboard",
      "/journey",
      "/other"
    ])

    Expect.to_have_text!(values(first_column), ["2", "2", "1", "1", "1"])
    Expect.to_have_text!(labels(second_column), ["/login"])
    Expect.to_have_text!(values(second_column), ["2"])
    Expect.to_have_text!(labels(third_column), ["No further action", "/dashboard"])
    Expect.to_have_text!(values(third_column), ["1", "1"])

    Test.step "filtering with journey matches in all 3 steps" do
      Locator.click!(devices_link.("Firefox"))

      Expect.to_have_text!(labels(first_column), ["/home"])
      Expect.to_have_text!(values(first_column), ["1"])
      Expect.to_have_text!(labels(second_column), ["/login"])
      Expect.to_have_text!(values(second_column), ["1"])
      Expect.to_have_text!(labels(third_column), ["/dashboard"])
      Expect.to_have_text!(values(third_column), ["1"])
      Expect.to_have_text!(fourth_column, ~r/No further steps found/)

      remove_filter.("Browser is Firefox")

      Expect.to_have_text!(labels(first_column), ["/home"])
      Expect.to_have_text!(values(first_column), ["2"])
      Expect.to_have_text!(labels(second_column), ["/login"])
      Expect.to_have_text!(values(second_column), ["2"])
      Expect.to_have_text!(labels(third_column), ["/dashboard"])
      Expect.to_have_text!(values(third_column), ["1"])
      Expect.to_have_text!(fourth_column, ~r/No further steps found/)
    end

    Test.step "filtering with journey matches for 2 first steps" do
      Locator.click!(devices_link.("Chrome"))

      Expect.to_have_text!(labels(first_column), ["/home"])
      Expect.to_have_text!(values(first_column), ["1"])
      Expect.to_have_text!(labels(second_column), ["/login"])
      Expect.to_have_text!(values(second_column), ["1"])
      Expect.to_have_text!(third_column, ~r/No further steps found/)
      Expect.to_be_hidden!(fourth_column)

      remove_filter.("Browser is Chrome")

      Expect.to_have_text!(labels(first_column), ["/home"])
      Expect.to_have_text!(values(first_column), ["2"])
      Expect.to_have_text!(labels(second_column), ["/login"])
      Expect.to_have_text!(values(second_column), ["2"])
      Expect.to_have_text!(labels(third_column), ["No further action", "/dashboard"])
      Expect.to_have_text!(values(third_column), ["1", "1"])
      expect_no_step(third_column, "/dashboard", "2")
      Expect.to_be_hidden!(fourth_column)
    end

    # select the 3rd step again
    third_column |> button("/dashboard") |> Locator.click!()
    expect_step(third_column, "/dashboard", "2")

    Test.step "filtering with journey with no matches for any of the steps" do
      Locator.click!(devices_link.("Safari"))

      Expect.to_have_text!(labels(first_column), ["/journey", "/other"])
      Expect.to_have_text!(values(first_column), ["1", "1"])
      Expect.to_have_text!(second_column, ~r/Select a starting point to continue/)
      Expect.to_have_text!(third_column, ~r/Select an event to continue/)
      Expect.to_be_hidden!(fourth_column)

      remove_filter.("Browser is Safari")

      Expect.to_have_text!(labels(first_column), [
        "/home",
        "/login",
        "/dashboard",
        "/journey",
        "/other"
      ])

      Expect.to_have_text!(values(first_column), ["2", "2", "1", "1", "1"])
      Expect.to_have_text!(second_column, ~r/Select a starting point to continue/)
      Expect.to_have_text!(third_column, ~r/Select an event to continue/)
      Expect.to_be_hidden!(fourth_column)
    end
  end
end
