defmodule PlausibleE2E.Dashboard.ExplorationSelectThreeStepsTest do
  use PlausibleE2E.Case, async: true

  import PlausibleE2E.ExplorationHelpers

  test "select entries in a 3-step journey", %{page: page, request: request} do
    %{report: report} =
      open_exploration(page, request, [
        ev(123, "/home", mins(40)),
        ev(123, "/login", mins(35)),
        ev(123, "/dashboard", mins(30)),
        ev(124, "/home", mins(35)),
        ev(124, "/login", mins(30)),
        ev(124, "/logout", mins(25)),
        ev(125, "/home", mins(35)),
        ev(125, "/login", mins(30)),
        ev(125, "/dashboard", mins(25)),
        ev(126, "/another-home", mins(40)),
        ev(126, "/journey", mins(35)),
        ev(126, "/somewhere", mins(30)),
        ev(127, "/home", mins(40)),
        ev(127, "/blog", mins(35)),
        ev(128, "/home", mins(40))
      ])

    Expect.to_be_visible!(Locator.get_by_test_id(report, "exploration-direction-forward"))

    first_column = column(report, 0)
    second_column = column(report, 1)
    third_column = column(report, 2)
    fourth_column = column(report, 3)

    Expect.to_have_text!(second_column, ~r/Select a starting point to continue/)

    first_column |> button("/home") |> Locator.click!()

    Expect.to_have_text!(labels(second_column), ["/login", "No further action", "/blog"])

    Test.step "filter for \"No further action\" in the second step" do
      second_column |> Locator.get_by_placeholder("Search") |> Locator.fill!("no further")
      Expect.to_have_text!(labels(second_column), ["No further action"])
    end

    second_column |> Locator.get_by_placeholder("Search") |> Locator.fill!("")

    Expect.to_have_text!(labels(second_column), ["/login", "No further action", "/blog"])

    Test.step "select an entry in the 2nd step" do
      second_column |> button("/login") |> Locator.click!()
      Expect.to_have_text!(labels(third_column), ["/dashboard", "/logout"])
      expect_step(second_column, "/login", "1")
    end

    Test.step "select a different entry in the 2nd step" do
      second_column |> button("/blog") |> Locator.click!()
      Expect.to_have_text!(third_column, ~r/No further steps found/)
      expect_step(second_column, "/blog", "1")
    end

    Test.step "deselect an entry in the 2nd step" do
      second_column |> button("/blog") |> Locator.click!()
      Expect.to_have_text!(third_column, ~r/Select an event to continue/)
      expect_no_step(second_column, "/blog", "1")
      Expect.to_have_text!(labels(second_column), ["/login", "No further action", "/blog"])
    end

    Test.step "select a different entry in the 1st step" do
      first_column |> button("/another-home") |> Locator.click!()
      expect_step(first_column, "/another-home", "0")
      Expect.to_have_text!(labels(second_column), ["/journey"])
      Expect.to_have_text!(third_column, ~r/Select an event to continue/)
    end

    Test.step "select an entry in the 2nd step and 3rd step" do
      second_column |> button("/journey") |> Locator.click!()
      Expect.to_have_text!(labels(third_column), ["/somewhere"])
      third_column |> button("/somewhere") |> Locator.click!()
      Expect.to_have_text!(fourth_column, ~r/No further steps found/)
    end

    Test.step "deselect an entry at the 1st step" do
      first_column |> button("/another-home") |> Locator.click!()

      Expect.to_have_text!(labels(first_column), [
        "/home",
        "/login",
        "/dashboard",
        "/another-home",
        "/blog",
        "/journey",
        "/logout",
        "/somewhere"
      ])

      expect_no_step(first_column, "/another-home", "0")
      Expect.to_have_text!(second_column, ~r/Select a starting point to continue/)
      Expect.to_have_text!(third_column, ~r/Select an event to continue/)
      Expect.to_be_hidden!(fourth_column)
    end
  end

  test "explore from end point", %{page: page, request: request} do
    %{report: report} =
      open_exploration(page, request, [
        ev(123, "/home", mins(40)),
        ev(123, "/login", mins(35)),
        ev(123, "/dashboard", mins(30)),
        ev(124, "/home", mins(35)),
        ev(124, "/login", mins(30)),
        ev(124, "/logout", mins(25)),
        ev(125, "/home", mins(35)),
        ev(125, "/login", mins(30)),
        ev(125, "/dashboard", mins(25)),
        ev(126, "/another-home", mins(40)),
        ev(126, "/journey", mins(35)),
        ev(126, "/somewhere", mins(30)),
        ev(127, "/home", mins(40)),
        ev(127, "/blog", mins(35)),
        ev(128, "/home", mins(40))
      ])

    first_step_suggestions = [
      "/home",
      "/login",
      "/dashboard",
      "/another-home",
      "/blog",
      "/journey",
      "/logout",
      "/somewhere"
    ]

    first_column = column(report, 0)
    second_column = column(report, 1)
    third_column = column(report, 2)
    fourth_column = column(report, 3)

    direction = fn d ->
      report |> Locator.get_by_test_id("exploration-direction-#{d}") |> Locator.click!()
    end

    Expect.to_have_text!(labels(first_column), first_step_suggestions)

    Test.step "switch to end point, back to start point and to end point again" do
      direction.("forward")
      direction.("backward")

      Expect.to_have_text!(labels(first_column), first_step_suggestions)
      expect_no_step(first_column, "/home", "0")
      Expect.to_have_text!(labels(first_column), first_step_suggestions)

      Expect.to_have_text!(second_column, ~r/1 step before/)
      Expect.to_have_text!(second_column, ~r/Select an end point to continue/)
      Expect.to_have_text!(third_column, ~r/2 steps before/)
      Expect.to_have_text!(third_column, ~r/Select an event to continue/)
      Expect.to_be_hidden!(fourth_column)

      direction.("backward")
      direction.("forward")

      Expect.to_have_text!(labels(first_column), first_step_suggestions)

      Expect.to_have_text!(second_column, ~r/1 step after/)
      Expect.to_have_text!(second_column, ~r/Select a starting point to continue/)
      Expect.to_have_text!(third_column, ~r/2 steps after/)
      Expect.to_have_text!(third_column, ~r/Select an event to continue/)
      Expect.to_be_hidden!(fourth_column)
    end

    Test.step "explore a 3-step journey from an end point" do
      direction.("forward")
      direction.("backward")

      Expect.to_have_text!(labels(first_column), first_step_suggestions)

      first_column |> button("/dashboard") |> Locator.click!()
      expect_step(first_column, "/dashboard", "0")
      Expect.to_have_text!(labels(second_column), ["/login"])
      Expect.to_have_text!(third_column, ~r/Select an event to continue/)

      second_column |> button("/login") |> Locator.click!()
      expect_step(second_column, "/login", "1")
      Expect.to_have_text!(labels(third_column), ["/home"])

      third_column |> button("/home") |> Locator.click!()
      expect_step(third_column, "/home", "2")
      Expect.to_have_text!(fourth_column, ~r/No further steps found/)
    end

    Test.step "switch back to starting point" do
      direction.("backward")
      direction.("forward")

      Expect.to_have_text!(labels(first_column), first_step_suggestions)
    end
  end
end
