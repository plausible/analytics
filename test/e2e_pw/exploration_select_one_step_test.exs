defmodule PlausibleE2E.Dashboard.ExplorationSelectOneStepTest do
  use PlausibleE2E.Case, async: true

  import PlausibleE2E.ExplorationHelpers

  test "select entries in a 1-step journey", %{page: page, request: request} do
    %{report: report} =
      open_exploration(page, request, [
        ev(123, "/home", mins(40)),
        ev(123, "/login", mins(35)),
        ev(123, "/dashboard", mins(30)),
        ev(124, "/home", mins(35)),
        ev(124, "/login", mins(30)),
        ev(125, "/home", mins(35)),
        ev(126, "/another-home", mins(40)),
        ev(126, "/journey", mins(35))
      ])

    Expect.to_be_visible!(Locator.get_by_test_id(report, "exploration-direction-forward"))

    first_column = column(report, 0)
    second_column = column(report, 1)

    Expect.to_have_text!(second_column, ~r/Select a starting point to continue/)

    Expect.to_have_text!(labels(first_column), [
      "/home",
      "/login",
      "/another-home",
      "/dashboard",
      "/journey"
    ])

    expect_no_step(first_column, "/home", "0")

    Test.step "select an entry" do
      first_column |> button("/login") |> Locator.click!()
      expect_step(first_column, "/login", "0")
      Expect.to_have_text!(labels(second_column), ["No further action", "/dashboard"])
    end

    Test.step "select a different entry" do
      first_column |> button("/another") |> Locator.click!()
      expect_step(first_column, "/another-home", "0")
      Expect.to_have_text!(labels(second_column), ["/journey"])
    end

    Test.step "select a different entry with no further steps" do
      first_column |> button("/dashboard") |> Locator.click!()
      expect_step(first_column, "/dashboard", "0")
      Expect.to_have_text!(second_column, ~r/No further steps found/)
    end

    Test.step "deselect an entry" do
      first_column |> button("/dashboard") |> Locator.click!()
      expect_no_step(first_column, "/dashboard", "0")
      Expect.to_have_text!(second_column, ~r/Select a starting point to continue/)
    end

    Test.step "filter entries with match" do
      first_column |> Locator.get_by_placeholder("Search") |> Locator.fill!("dash")
      Expect.to_have_text!(labels(first_column), ["/dashboard"])
    end

    Test.step "filter entries with no match" do
      first_column |> Locator.get_by_placeholder("Search") |> Locator.fill!("nosuchthing")
      Expect.to_have_text!(first_column, ~r/No events found/)
    end

    Test.step "filter returning more than one entry" do
      first_column |> Locator.get_by_placeholder("Search") |> Locator.fill!("home")
      Expect.to_have_text!(labels(first_column), ["/home", "/another-home"])
    end

    Test.step "select an entry with filtering applied" do
      first_column |> button("/home") |> Locator.click!()
      Expect.to_have_text!(labels(second_column), ["/login", "No further action"])
      Expect.to_have_text!(labels(first_column), ["/home", "/another-home"])
      expect_step(first_column, "/home", "0")
    end

    Test.step "select another entry with filtering still applied" do
      first_column |> button("/another-home") |> Locator.click!()
      Expect.to_have_text!(labels(second_column), ["/journey"])
      Expect.to_have_text!(labels(first_column), ["/home", "/another-home"])
      expect_step(first_column, "/another-home", "0")
    end

    Test.step "deselect an entry with filtering still applied" do
      first_column |> button("/another-home") |> Locator.click!()

      Expect.to_have_text!(labels(first_column), [
        "/home",
        "/login",
        "/another-home",
        "/dashboard",
        "/journey"
      ])

      expect_no_step(first_column, "/another-home", "0")
      Expect.to_have_text!(second_column, ~r/Select a starting point to continue/)
    end
  end
end
