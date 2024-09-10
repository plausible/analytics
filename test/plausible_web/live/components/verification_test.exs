defmodule PlausibleWeb.Live.Components.VerificationTest do
  use PlausibleWeb.ConnCase, async: true
  import Plausible.LiveViewTest, only: [render_component: 2]
  import Plausible.Test.Support.HTML

  @component PlausibleWeb.Live.Components.Verification
  @progress ~s|#progress-indicator p#progress|

  @pulsating_circle ~s|div#progress-indicator div.pulsating-circle|
  @check_circle ~s|div#progress-indicator #check-circle|
  @error_circle ~s|div#progress-indicator #error-circle|
  @recommendations ~s|#recommendation|
  @super_admin_report ~s|#super-admin-report|

  test "renders initial state" do
    html = render_component(@component, domain: "example.com")
    assert element_exists?(html, @progress)

    assert text_of_element(html, @progress) ==
             "We're visiting your site to ensure that everything is working"

    assert element_exists?(html, @pulsating_circle)
    refute class_of_element(html, @pulsating_circle) =~ "hidden"
    refute element_exists?(html, @recommendations)
    refute element_exists?(html, @check_circle)
    refute element_exists?(html, @super_admin_report)
  end

  test "renders error badge on error" do
    html = render_component(@component, domain: "example.com", success?: false, finished?: true)
    refute element_exists?(html, @pulsating_circle)
    refute element_exists?(html, @check_circle)
    refute element_exists?(html, @recommendations)
    assert element_exists?(html, @error_circle)
  end

  test "renders diagnostic interpretation" do
    interpretation =
      Plausible.Verification.Checks.interpret_diagnostics(%Plausible.Verification.State{
        url: "example.com"
      })

    html =
      render_component(@component,
        domain: "example.com",
        success?: false,
        finished?: true,
        interpretation: interpretation
      )

    recommendations = html |> find(@recommendations) |> Enum.map(&text/1)

    assert recommendations == [
             "If your site is running at a different location, please manually check your integration.  Learn more"
           ]

    refute element_exists?(html, @super_admin_report)
  end

  test "renders super-admin report" do
    state = %Plausible.Verification.State{
      url: "example.com"
    }

    interpretation =
      Plausible.Verification.Checks.interpret_diagnostics(state)

    html =
      render_component(@component,
        domain: "example.com",
        success?: false,
        finished?: true,
        interpretation: interpretation,
        verification_state: state,
        super_admin?: true
      )

    assert element_exists?(html, @super_admin_report)
    assert text_of_element(html, @super_admin_report) =~ "Snippets found in body: 0"
  end

  test "hides pulsating circle when finished, shows check circle" do
    html =
      render_component(@component,
        domain: "example.com",
        success?: true,
        finished?: true
      )

    refute element_exists?(html, @pulsating_circle)
    assert element_exists?(html, @check_circle)
  end

  test "renders a progress message" do
    html = render_component(@component, domain: "example.com", message: "Arbitrary message")

    assert text_of_element(html, @progress) == "Arbitrary message"
  end

  @tag :ee_only
  test "renders contact link on >3 attempts" do
    html = render_component(@component, domain: "example.com", attempts: 2, finished?: true)
    refute html =~ "Need further help with your installation?"
    refute element_exists?(html, ~s|a[href="https://plausible.io/contact"]|)

    html = render_component(@component, domain: "example.com", attempts: 3, finished?: true)
    assert html =~ "Need further help with your installation?"
    assert element_exists?(html, ~s|a[href="https://plausible.io/contact"]|)
  end

  test "offers escape paths: settings and installation instructions on failure" do
    html =
      render_component(@component,
        domain: "example.com",
        success?: false,
        finished?: true,
        installation_type: "WordPress",
        flow: PlausibleWeb.Flows.review()
      )

    assert element_exists?(html, ~s|a[href="/example.com/settings/general"]|)

    assert element_exists?(
             html,
             ~s|a[href="/example.com/installation?flow=review&installation_type=WordPress"]|
           )
  end
end
