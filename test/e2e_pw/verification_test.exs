defmodule PlausibleE2E.Dashboard.VerificationTest do
  use PlausibleE2E.Case, async: true

  @verification_banner_selector "#verification-ui"
  @progress_msg_selector "#progress"
  @heading_selector "h3"

  @success_message "Tracking is active on your site"
  @failure_heading "We couldn't detect Plausible on your site"
  @loading_state_title "Verifying your installation"
  @loading_state_cycled_messages [
    ~r/We're visiting your site to ensure that everything is working/,
    ~r/We're trying to reach your website/,
    ~r/We're verifying that your visitors are being counted correctly/
  ]

  test "installation verification", %{page: page, request: request} do
    %{domain: domain} = setup_site(page: page, request: request)

    other_domain = "#{random_id()}.other.verification.com"
    add_site(page: page, domain: other_domain)

    banner = Page.locator(page, @verification_banner_selector)
    progress = Locator.locator(banner, @progress_msg_selector)
    heading = Locator.locator(banner, @heading_selector)

    Test.step "restarts when the page is refreshed while verification is ongoing" do
      set_verification_scenario(
        request: request,
        domain: domain,
        scenario: "plausible_not_found",
        options: %{slowdown: 500, launch_delay: 500}
      )

      Page.goto!(page, "/#{domain}?verify_installation=true", wait_until: :commit)
      expect_live_view_connected(page)

      Expect.to_contain_text!(banner, @loading_state_title)
      Expect.to_have_text!(progress, Enum.at(@loading_state_cycled_messages, 0))
      Expect.to_have_text!(progress, Enum.at(@loading_state_cycled_messages, 1))

      Page.reload!(page, wait_until: :commit)
      expect_live_view_connected(page)

      Expect.to_contain_text!(banner, @loading_state_title)

      for msg <- @loading_state_cycled_messages do
        Expect.to_have_text!(progress, msg)
      end
    end

    Test.step "when finished with failure, refreshing kicks off verification again" do
      Expect.to_have_text!(heading, @failure_heading)

      Page.reload!(page, wait_until: :commit)
      expect_live_view_connected(page)

      Expect.to_contain_text!(banner, @loading_state_title)
    end

    Test.step ~s|"Try another URL" reveals the custom URL form instantly, client-side, submitting it kicks off a new run| do
      set_verification_scenario(request: request, domain: domain, scenario: "domain_not_found")

      Page.goto!(page, "/#{domain}?verify_installation=true", wait_until: :commit)
      expect_live_view_connected(page)

      default_actions = Locator.locator(banner, "#verification-failed-default-actions")
      custom_url_form = Locator.locator(banner, "#custom-url-form")
      try_another_url_link = Locator.get_by_role(banner, :link, name: "Try another URL")

      Expect.to_be_visible!(try_another_url_link)
      Expect.to_be_hidden!(custom_url_form)
      Expect.to_have_text!(heading, "We couldn't reach https://#{domain}")

      Locator.click!(try_another_url_link)

      Expect.to_be_visible!(custom_url_form)
      Expect.to_be_hidden!(default_actions)

      different_url = "https://differenturl.com"

      custom_url_form
      |> Locator.locator(~s|input[name="custom_url"]|)
      |> Locator.fill!(different_url)

      custom_url_form |> Locator.get_by_role(:button, name: "Verify URL") |> Locator.click!()

      Expect.to_have_text!(heading, "We couldn't reach #{different_url}")
    end

    Test.step "navigating to the dashboard via the site switcher kicks off verification again" do
      set_verification_scenario(request: request, domain: domain, scenario: "success")

      Page.goto!(page, "/#{other_domain}", wait_until: :commit)

      Page.get_by_role(page, :button, name: other_domain) |> Locator.click!()

      page
      |> Page.get_by_test_id("sitemenu")
      |> Locator.get_by_role(:link, name: Regex.compile!(domain))
      |> Locator.click!()

      Expect.to_have_url!(
        page,
        Regex.compile!("#{domain}\\?verify_installation=true&flow=provisioning")
      )

      expect_live_view_connected(page)

      Expect.to_contain_text!(banner, @success_message)
    end

    Test.step "when finished with success, a page refresh won't bring it back" do
      Page.reload!(page, wait_until: :commit)

      Expect.to_have_count!(Page.locator(page, @verification_banner_selector), 0)
    end

    Test.step "flow=review, dismissing while in progress: refresh won't bring it back" do
      set_verification_scenario(
        request: request,
        domain: domain,
        scenario: "success",
        options: %{slowdown: 3000}
      )

      Page.goto!(page, "/#{domain}?verify_installation=true&flow=review", wait_until: :commit)
      expect_live_view_connected(page)

      Expect.to_contain_text!(banner, @loading_state_title)

      banner |> Locator.get_by_role(:button, name: "Dismiss") |> Locator.click!()

      Expect.to_be_hidden!(banner)
      Expect.not_to_have_url!(page, ~r/verify_installation/)
      Expect.not_to_have_url!(page, ~r/flow=/)

      Page.reload!(page, wait_until: :commit)

      Expect.to_have_count!(Page.locator(page, @verification_banner_selector), 0)
    end

    Test.step "flow=review, finished with failure: refresh kicks off verification again" do
      set_verification_scenario(request: request, domain: domain, scenario: "plausible_not_found")

      Page.goto!(page, "/#{domain}?verify_installation=true&flow=review", wait_until: :commit)
      expect_live_view_connected(page)

      Expect.to_have_text!(heading, @failure_heading)

      Page.reload!(page, wait_until: :commit)
      expect_live_view_connected(page)

      Expect.to_have_text!(heading, @failure_heading)
    end

    Test.step "flow=domain_change, dismissing after finished with failure: refresh won't bring it back" do
      Page.goto!(page, "/#{domain}?verify_installation=true&flow=domain_change",
        wait_until: :commit
      )

      expect_live_view_connected(page)

      Expect.to_have_text!(heading, @failure_heading)

      banner |> Locator.get_by_role(:button, name: "Dismiss") |> Locator.click!()

      Expect.to_be_hidden!(banner)
      Expect.not_to_have_url!(page, ~r/verify_installation/)
      Expect.not_to_have_url!(page, ~r/flow=/)

      Page.reload!(page, wait_until: :commit)

      Expect.to_have_count!(Page.locator(page, @verification_banner_selector), 0)
    end

    Test.step "flow=domain_change, finished with success: refresh won't bring it back" do
      set_verification_scenario(request: request, domain: domain, scenario: "success")

      Page.goto!(page, "/#{domain}?verify_installation=true&flow=domain_change",
        wait_until: :commit
      )

      expect_live_view_connected(page)

      Expect.to_contain_text!(banner, @success_message)

      Page.reload!(page, wait_until: :commit)

      Expect.to_have_count!(Page.locator(page, @verification_banner_selector), 0)
    end
  end
end
