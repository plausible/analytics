defmodule PlausibleWeb.Live.Components.VerificationBannerTest do
  use PlausibleWeb.ConnCase, async: true

  on_ee do
    import Phoenix.LiveViewTest, only: [render_component: 2]

    alias Plausible.InstallationSupport.{State, Verification}

    @moduletag :capture_log

    @component PlausibleWeb.Live.Components.VerificationBanner
    @progress ~s|#verification-ui p#progress|

    @loading_spinner ~s|#verification-ui svg.animate-spin|
    @check_circle ~s|#verification-ui #check-circle|
    @recommendations ~s|#recommendation|
    @super_admin_report ~s|#super-admin-report|

    test "renders initial state" do
      html = render_component(@component, domain: "example.com")
      assert element_exists?(html, @progress)

      assert text_of_element(html, @progress) ==
               "We're visiting your site to ensure that everything is working..."

      assert element_exists?(html, @loading_spinner)
      refute element_exists?(html, @recommendations)
      refute element_exists?(html, @check_circle)
      refute element_exists?(html, @super_admin_report)
    end

    test "renders failed state without progress spinner" do
      html = render_component(@component, domain: "example.com", success?: false, finished?: true)
      refute element_exists?(html, @loading_spinner)
      refute element_exists?(html, @check_circle)
      refute element_exists?(html, @recommendations)
      assert html =~ "We couldn&#39;t verify your installation"
    end

    test "renders diagnostic interpretation with inline verify/review links" do
      interpretation =
        Verification.Checks.interpret_diagnostics(%State{
          url: "https://example.com",
          data_domain: "example.com",
          diagnostics: %Verification.Diagnostics{service_error: %{code: :domain_not_found}}
        })

      html =
        render_component(@component,
          domain: "example.com",
          success?: false,
          finished?: true,
          interpretation: interpretation
        )

      assert [recommendation] = html |> find(@recommendations) |> Enum.map(&text/1)
      assert recommendation =~ "Check that the URL is correct and publicly accessible"
      assert recommendation =~ "verify your installation manually"
      assert recommendation =~ "review your installation"

      assert element_exists?(
               html,
               ~s|#recommendation a[href="https://plausible.io/docs/troubleshoot-integration#how-to-manually-check-your-integration"]|
             )

      assert element_exists?(
               html,
               ~s|#recommendation a[href="/example.com/installation?flow="]|
             )

      refute element_exists?(html, @super_admin_report)
    end

    test "renders inline verify-manually link when the recommendation mentions it (no custom URL retry)" do
      interpretation =
        Verification.Checks.interpret_diagnostics(%State{
          url: "https://example.com",
          data_domain: "example.com",
          diagnostics: %Verification.Diagnostics{
            plausible_is_on_window: false,
            selected_installation_type: "manual"
          }
        })

      refute Map.get(interpretation.data || %{}, :offer_custom_url_input) == true

      html =
        render_component(@component,
          domain: "example.com",
          success?: false,
          finished?: true,
          interpretation: interpretation
        )

      assert [recommendation] = html |> find(@recommendations) |> Enum.map(&text/1)
      assert recommendation =~ "Make sure you've copied the snippet"
      assert recommendation =~ "verify your installation manually"
      refute recommendation =~ "review your installation"
      refute recommendation =~ "Learn more"

      assert element_exists?(
               html,
               ~s|#recommendation a[href="https://plausible.io/docs/troubleshoot-integration#how-to-manually-check-your-integration"]|
             )

      refute element_exists?(html, ~s|#recommendation a[href^="/example.com/installation"]|)
    end

    test "renders super-admin report" do
      state = %State{
        url: "https://example.com",
        data_domain: "example.com",
        diagnostics: %Verification.Diagnostics{}
      }

      interpretation = Verification.Checks.interpret_diagnostics(state)

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
      assert text_of_element(html, @super_admin_report) =~ "Plausible is on window: nil"
    end

    test "hides pulsating circle when finished, shows check circle" do
      html =
        render_component(@component,
          domain: "example.com",
          success?: true,
          finished?: true
        )

      refute element_exists?(html, @loading_spinner)
      assert element_exists?(html, @check_circle)
    end

    test "renders a progress message" do
      html = render_component(@component, domain: "example.com", message: "Arbitrary message")

      assert text_of_element(html, @progress) == "Arbitrary message..."
    end

    test "renders contact link on >=3 attempts" do
      html = render_component(@component, domain: "example.com", attempts: 2, finished?: true)
      refute html =~ "Need help?"
      refute element_exists?(html, ~s|a[href="https://plausible.io/contact"]|)

      html = render_component(@component, domain: "example.com", attempts: 3, finished?: true)
      assert html =~ "Need help?"
      assert element_exists?(html, ~s|a[href="https://plausible.io/contact"]|)
    end

    test "renders a Try another URL ghost button when a custom URL retry is offered" do
      interpretation =
        Verification.Checks.interpret_diagnostics(%State{
          url: "example.com",
          diagnostics: %Verification.Diagnostics{
            plausible_is_on_window: false,
            plausible_is_initialized: false,
            service_error: %{code: :domain_not_found}
          }
        })

      assert interpretation.data.offer_custom_url_input == true

      html =
        render_component(@component,
          domain: "example.com",
          finished?: true,
          success?: false,
          interpretation: interpretation
        )

      assert text_of_element(html, "#verify-custom-url-link") =~ "Try another URL"
      assert element_exists?(html, ~s|a#verify-custom-url-link[phx-click="show-custom-url-form"]|)
      refute html =~ "Review installation"
    end

    test "renders the custom URL input inline, replacing Check again with the Verify URL submit button, and hides the secondary action" do
      interpretation =
        Verification.Checks.interpret_diagnostics(%State{
          url: "example.com",
          diagnostics: %Verification.Diagnostics{
            plausible_is_on_window: false,
            plausible_is_initialized: false,
            service_error: %{code: :domain_not_found}
          }
        })

      html =
        render_component(@component,
          domain: "example.com",
          finished?: true,
          success?: false,
          interpretation: interpretation,
          custom_url_input?: true
        )

      refute element_exists?(html, "#verify-custom-url-link")
      refute element_exists?(html, ~s|a[phx-click="retry"]|)
      refute html =~ "Review installation"

      assert text_of_element(html, ~s|form[phx-submit="verify-custom-url"] button[type="submit"]|) =~
               "Verify URL"

      assert element_exists?(
               html,
               ~s|form[phx-submit="verify-custom-url"] input[name="custom_url"]|
             )

      assert text_of_attr(html, ~s|form[phx-submit="verify-custom-url"] input|, "value") =~
               "https://example.com"
    end

    test "offers a Review installation ghost button on failure by default" do
      html =
        render_component(@component,
          domain: "example.com",
          success?: false,
          finished?: true,
          flow: PlausibleWeb.Flows.review()
        )

      refute element_exists?(html, ~s|a[href="/example.com/settings/general"]|)

      assert element_exists?(
               html,
               ~s|a[href="/example.com/installation?flow=review"]|
             )

      assert html =~ "Review installation"
    end
  end
end
