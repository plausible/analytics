defmodule PlausibleWeb.Live.Components.VerificationTest do
  use PlausibleWeb.ConnCase, async: true
  import Phoenix.LiveViewTest, only: [render_component: 2]
  import Plausible.Test.Support.HTML

  alias Plausible.InstallationSupport.{State, LegacyVerification, Verification}

  @component PlausibleWeb.Live.Components.Verification
  @progress ~s|#verification-ui p#progress|

  @pulsating_circle ~s|div#verification-ui div.pulsating-circle|
  @check_circle ~s|div#verification-ui #check-circle|
  @error_circle ~s|div#verification-ui #error-circle|
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
      LegacyVerification.Checks.interpret_diagnostics(%State{
        url: "example.com",
        diagnostics: %LegacyVerification.Diagnostics{}
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
    state = %State{
      url: "example.com",
      diagnostics: %LegacyVerification.Diagnostics{}
    }

    interpretation =
      LegacyVerification.Checks.interpret_diagnostics(state)

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

  test "renders link to verify installation at a different URL" do
    interpretation =
      Verification.Checks.interpret_diagnostics(%State{
        url: "example.com",
        diagnostics: %Verification.Diagnostics{
          plausible_is_on_window: false,
          plausible_is_initialized: false,
          service_error: :domain_not_found
        }
      })

    assert interpretation.data.offer_custom_url_input == true

    expected_link_href =
      PlausibleWeb.Router.Helpers.site_path(PlausibleWeb.Endpoint, :verification, "example.com")

    html =
      render_component(@component,
        domain: "example.com",
        finished?: true,
        success?: false,
        interpretation: interpretation
      )

    assert text_of_element(html, "#verify-custom-url-link") =~ "different URL?"
    assert text_of_attr(html, "#verify-custom-url-link a", "href") =~ expected_link_href
    assert text_of_attr(html, "#verify-custom-url-link a", "href") =~ "custom_url=true"
  end

  test "offers escape paths: settings and installation instructions on failure" do
    html =
      render_component(@component,
        domain: "example.com",
        success?: false,
        finished?: true,
        installation_type: "wordpress",
        flow: PlausibleWeb.Flows.review()
      )

    assert element_exists?(html, ~s|a[href="/example.com/settings/general"]|)

    assert element_exists?(
             html,
             ~s|a[href="/example.com/installation?flow=review&installation_type=wordpress"]|
           )
  end
end
