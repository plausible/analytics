defmodule PlausibleWeb.Live.ChoosePlanTest do
  use PlausibleWeb.ConnCase, async: true

  on_ee do
    use Plausible.Teams.Test
    @moduletag :ee_only

    import Phoenix.LiveViewTest
    import Plausible.Test.Support.HTML
    require Plausible.Billing.Subscription.Status
    alias Plausible.{Repo, Billing, Billing.Subscription}

    @v1_10k_yearly_plan_id "572810"
    @v1_50m_yearly_plan_id "650653"
    @v2_20m_yearly_plan_id "653258"
    @v5_starter_5m_monthly_plan_id "910425"
    @v4_growth_10k_monthly_plan_id "857097"
    @v4_growth_200k_yearly_plan_id "857081"
    @v5_growth_10k_yearly_plan_id "910430"
    @v5_growth_200k_yearly_plan_id "910434"
    @v4_business_5m_monthly_plan_id "857111"
    @v5_business_5m_monthly_plan_id "910457"
    @v3_business_10k_monthly_plan_id "857481"

    @monthly_interval_button ~s/label[phx-click="set_interval"][phx-value-interval="monthly"]/
    @yearly_interval_button ~s/label[phx-click="set_interval"][phx-value-interval="yearly"]/
    @interval_button_active_class "bg-indigo-600 text-white"
    @slider_input ~s/input[name="slider"]/
    @slider_value "#slider-value"

    @starter_plan_box "#starter-plan-box"
    @starter_plan_tooltip "#starter-plan-box .tooltip-content"
    @starter_price_tag_amount "#starter-price-tag-amount"
    @starter_price_tag_interval "#starter-price-tag-interval"
    @starter_discount_price_tag_amount "#starter-discount-price-tag-amount"
    @starter_discount_price_tag_strikethrough_amount "#starter-discount-price-tag-strikethrough-amount"
    @starter_vat_notice "#starter-vat-notice"
    @starter_highlight_pill "#{@starter_plan_box} #highlight-pill"
    @starter_checkout_button "#starter-checkout"

    @growth_plan_box "#growth-plan-box"
    @growth_plan_tooltip "#growth-plan-box .tooltip-content"
    @growth_price_tag_amount "#growth-price-tag-amount"
    @growth_price_tag_interval "#growth-price-tag-interval"
    @growth_discount_price_tag_amount "#growth-discount-price-tag-amount"
    @growth_discount_price_tag_strikethrough_amount "#growth-discount-price-tag-strikethrough-amount"
    @growth_vat_notice "#growth-vat-notice"
    @growth_highlight_pill "#{@growth_plan_box} #highlight-pill"
    @growth_checkout_button "#growth-checkout"

    @business_plan_box "#business-plan-box"
    @business_price_tag_amount "#business-price-tag-amount"
    @business_price_tag_interval "#business-price-tag-interval"
    @business_discount_price_tag_amount "#business-discount-price-tag-amount"
    @business_discount_price_tag_strikethrough_amount "#business-discount-price-tag-strikethrough-amount"
    @business_vat_notice "#business-vat-notice"
    @business_highlight_pill "#{@business_plan_box} #highlight-pill"
    @business_checkout_button "#business-checkout"

    @enterprise_plan_box "#enterprise-plan-box"
    @enterprise_highlight_pill "#enterprise-highlight-pill"

    @slider_volumes ["10k", "100k", "200k", "500k", "1M", "2M", "5M", "10M", "10M+"]

    describe "for a user with no subscription" do
      setup [:create_user, :create_site, :log_in]

      setup %{user: user} do
        {:ok, team} = Plausible.Teams.get_or_create(user)

        trial_expiry_date = Plausible.Teams.Billing.starter_tier_launch() |> Date.shift(day: -30)

        Ecto.Changeset.change(team, %{trial_expiry_date: trial_expiry_date})
        |> Repo.update()

        :ok
      end

      test "displays basic page content", %{conn: conn} do
        {:ok, _lv, doc} = get_liveview(conn)

        assert doc =~ "Upgrade your trial"
        assert doc =~ "Back to Settings"
        assert doc =~ "You have used"
        assert doc =~ "<b>0</b>"
        assert doc =~ "billable pageviews in the last 30 days"
        assert doc =~ "Any other questions?"
        assert doc =~ "What happens if I go over my monthly pageview limit?"
        assert doc =~ "Enterprise"
        assert doc =~ "+ VAT"
      end

      test "does not render any global notices", %{conn: conn} do
        {:ok, _lv, doc} = get_liveview(conn)
        check_notice_titles(doc, [])
      end

      test "displays plan benefits", %{conn: conn} do
        {:ok, _lv, doc} = get_liveview(conn)

        starter_box = text_of_element(doc, @starter_plan_box)
        growth_box = text_of_element(doc, @growth_plan_box)
        business_box = text_of_element(doc, @business_plan_box)
        enterprise_box = text_of_element(doc, @enterprise_plan_box)

        assert starter_box =~ "Intuitive, fast and privacy-friendly dashboard"
        assert starter_box =~ "Email/Slack reports"
        assert starter_box =~ "Google Analytics import"
        assert starter_box =~ "Goals and custom events"
        assert starter_box =~ "One site"
        assert starter_box =~ "3 years of data retention"

        assert growth_box =~ "Up to 3 team members"
        assert growth_box =~ "Up to 3 sites"
        assert growth_box =~ "Team Management"
        assert growth_box =~ "Shared Links"
        assert growth_box =~ "Shared Segments"

        assert business_box =~ "Everything in Growth"
        assert business_box =~ "Up to 10 team members"
        assert business_box =~ "Up to 10 sites"
        assert business_box =~ "Stats API (600 requests per hour)"
        assert business_box =~ "Looker Studio Connector"
        assert business_box =~ "Custom Properties"
        assert business_box =~ "Funnels"
        assert business_box =~ "Ecommerce revenue attribution"

        refute business_box =~ "Goals and custom events"

        assert enterprise_box =~ "Everything in Business"
        assert enterprise_box =~ "10+ team members"
        assert enterprise_box =~ "10+ sites"
        assert enterprise_box =~ "600+ Stats API requests per hour"
        assert enterprise_box =~ "Sites API access for"
        assert enterprise_box =~ "Technical onboarding"
        assert enterprise_box =~ "Priority support"

        assert text_of_attr(find(doc, "#{@enterprise_plan_box} p a"), "href") =~
                 "https://plausible.io/white-label-web-analytics"
      end

      test "default billing interval is yearly, and can switch to monthly", %{conn: conn} do
        {:ok, lv, doc} = get_liveview(conn)

        assert class_of_element(doc, @yearly_interval_button) =~ @interval_button_active_class
        refute class_of_element(doc, @monthly_interval_button) =~ @interval_button_active_class

        doc = element(lv, @monthly_interval_button) |> render_click()

        refute class_of_element(doc, @yearly_interval_button) =~ @interval_button_active_class
        assert class_of_element(doc, @monthly_interval_button) =~ @interval_button_active_class
      end

      test "default pageview limit is 10k", %{conn: conn} do
        {:ok, _lv, doc} = get_liveview(conn)
        assert text_of_element(doc, @slider_value) == "10k"
        assert text_of_element(doc, @starter_price_tag_amount) == "€90"
        assert text_of_element(doc, @growth_price_tag_amount) == "€140"
        assert text_of_element(doc, @business_price_tag_amount) == "€190"
      end

      test "pageview slider changes selected volume and prices shown", %{conn: conn} do
        {:ok, lv, _doc} = get_liveview(conn)

        doc = set_slider(lv, "100k")
        assert text_of_element(doc, @slider_value) == "100k"
        assert text_of_element(doc, @starter_price_tag_amount) == "€190"
        assert text_of_element(doc, @growth_price_tag_amount) == "€290"
        assert text_of_element(doc, @business_price_tag_amount) == "€390"

        doc = set_slider(lv, "200k")
        assert text_of_element(doc, @slider_value) == "200k"
        assert text_of_element(doc, @starter_price_tag_amount) == "€290"
        assert text_of_element(doc, @growth_price_tag_amount) == "€440"
        assert text_of_element(doc, @business_price_tag_amount) == "€590"

        doc = set_slider(lv, "500k")
        assert text_of_element(doc, @slider_value) == "500k"
        assert text_of_element(doc, @starter_price_tag_amount) == "€490"
        assert text_of_element(doc, @growth_price_tag_amount) == "€740"
        assert text_of_element(doc, @business_price_tag_amount) == "€990"

        doc = set_slider(lv, "1M")
        assert text_of_element(doc, @slider_value) == "1M"
        assert text_of_element(doc, @starter_price_tag_amount) == "€690"
        assert text_of_element(doc, @growth_price_tag_amount) == "€1,040"
        assert text_of_element(doc, @business_price_tag_amount) == "€1,390"

        doc = set_slider(lv, "2M")
        assert text_of_element(doc, @slider_value) == "2M"
        assert text_of_element(doc, @starter_price_tag_amount) == "€890"
        assert text_of_element(doc, @growth_price_tag_amount) == "€1,340"
        assert text_of_element(doc, @business_price_tag_amount) == "€1,790"

        doc = set_slider(lv, "5M")
        assert text_of_element(doc, @slider_value) == "5M"
        assert text_of_element(doc, @starter_price_tag_amount) == "€1,290"
        assert text_of_element(doc, @growth_price_tag_amount) == "€1,940"
        assert text_of_element(doc, @business_price_tag_amount) == "€2,590"

        doc = set_slider(lv, "10M")
        assert text_of_element(doc, @slider_value) == "10M"
        assert text_of_element(doc, @starter_price_tag_amount) == "€1,690"
        assert text_of_element(doc, @growth_price_tag_amount) == "€2,540"
        assert text_of_element(doc, @business_price_tag_amount) == "€3,390"
      end

      test "displays monthly discount for yearly plans", %{conn: conn} do
        {:ok, lv, _doc} = get_liveview(conn)

        doc = set_slider(lv, "200k")

        assert text_of_element(doc, @starter_price_tag_amount) == "€290"
        assert text_of_element(doc, @starter_discount_price_tag_amount) == "€24.17"
        assert text_of_element(doc, @starter_discount_price_tag_strikethrough_amount) == "€29"
        assert text_of_element(doc, @starter_vat_notice) == "+ VAT if applicable"

        assert text_of_element(doc, @growth_price_tag_amount) == "€440"
        assert text_of_element(doc, @growth_discount_price_tag_amount) == "€36.67"
        assert text_of_element(doc, @growth_discount_price_tag_strikethrough_amount) == "€44"
        assert text_of_element(doc, @growth_vat_notice) == "+ VAT if applicable"

        assert text_of_element(doc, @business_price_tag_amount) == "€590"
        assert text_of_element(doc, @business_discount_price_tag_amount) == "€49.17"
        assert text_of_element(doc, @business_discount_price_tag_strikethrough_amount) == "€59"
        assert text_of_element(doc, @business_vat_notice) == "+ VAT if applicable"
      end

      test "renders contact links for all tiers when enterprise-level volume selected",
           %{
             conn: conn
           } do
        {:ok, lv, _doc} = get_liveview(conn)

        doc = set_slider(lv, "10M+")

        assert text_of_element(doc, "#starter-custom-price") =~ "Custom"
        assert text_of_element(doc, @starter_plan_box) =~ "Contact us"
        assert text_of_element(doc, "#growth-custom-price") =~ "Custom"
        assert text_of_element(doc, @growth_plan_box) =~ "Contact us"
        assert text_of_element(doc, "#business-custom-price") =~ "Custom"
        assert text_of_element(doc, @business_plan_box) =~ "Contact us"

        doc = set_slider(lv, "10M")

        refute text_of_element(doc, "#starter-custom-price") =~ "Custom"
        refute text_of_element(doc, @starter_plan_box) =~ "Contact us"
        refute text_of_element(doc, "#growth-custom-price") =~ "Custom"
        refute text_of_element(doc, @growth_plan_box) =~ "Contact us"
        refute text_of_element(doc, "#business-custom-price") =~ "Custom"
        refute text_of_element(doc, @business_plan_box) =~ "Contact us"
      end

      test "switching billing interval changes prices", %{conn: conn} do
        {:ok, lv, doc} = get_liveview(conn)

        assert text_of_element(doc, @starter_price_tag_amount) == "€90"
        assert text_of_element(doc, @starter_price_tag_interval) == "/year"

        assert text_of_element(doc, @growth_price_tag_amount) == "€140"
        assert text_of_element(doc, @growth_price_tag_interval) == "/year"

        assert text_of_element(doc, @business_price_tag_amount) == "€190"
        assert text_of_element(doc, @business_price_tag_interval) == "/year"

        doc = element(lv, @monthly_interval_button) |> render_click()

        assert text_of_element(doc, @starter_price_tag_amount) == "€9"
        assert text_of_element(doc, @starter_price_tag_interval) == "/month"

        assert text_of_element(doc, @growth_price_tag_amount) == "€14"
        assert text_of_element(doc, @growth_price_tag_interval) == "/month"

        assert text_of_element(doc, @business_price_tag_amount) == "€19"
        assert text_of_element(doc, @business_price_tag_interval) == "/month"
      end

      test "checkout buttons are 'paddle buttons' with dynamic onclick attribute", %{
        conn: conn,
        user: user
      } do
        {:ok, lv, _doc} = get_liveview(conn)
        {:ok, team} = Plausible.Teams.get_by_owner(user)

        set_slider(lv, "200k")
        doc = element(lv, @yearly_interval_button) |> render_click()

        assert %{
                 "disableLogout" => true,
                 "email" => user.email,
                 "passthrough" => "ee:true;user:#{user.id};team:#{team.id}",
                 "product" => @v5_growth_200k_yearly_plan_id,
                 "success" => Routes.billing_path(PlausibleWeb.Endpoint, :upgrade_success),
                 "theme" => "none"
               } == get_paddle_checkout_params(find(doc, @growth_checkout_button))

        set_slider(lv, "5M")
        doc = element(lv, @monthly_interval_button) |> render_click()

        assert get_paddle_checkout_params(find(doc, @starter_checkout_button))["product"] ==
                 @v5_starter_5m_monthly_plan_id

        assert get_paddle_checkout_params(find(doc, @business_checkout_button))["product"] ==
                 @v5_business_5m_monthly_plan_id
      end

      test "warns about losing access to a feature", %{conn: conn, site: site} do
        Plausible.Props.allow(site, ["author"])

        {:ok, _lv, doc} = get_liveview(conn)

        assert text_of_attr(find(doc, @growth_checkout_button), "onclick") =~
                 "if (confirm(\"This plan does not support Custom Properties, which you have been using. By subscribing to this plan, you will not have access to this feature.\")) {Paddle.Checkout.open"
      end

      test "recommends Starter", %{conn: conn} do
        {:ok, _lv, doc} = get_liveview(conn)

        assert text_of_element(doc, @starter_highlight_pill) == "Recommended"
        refute element_exists?(doc, @growth_highlight_pill)
        refute element_exists?(doc, @business_highlight_pill)
      end

      test "recommends Growth", %{conn: conn, site: site} do
        for _ <- 1..3, do: add_guest(site, role: :viewer)

        {:ok, _lv, doc} = get_liveview(conn)

        refute element_exists?(doc, @starter_highlight_pill)
        assert text_of_element(doc, @growth_highlight_pill) == "Recommended"
        refute element_exists?(doc, @business_highlight_pill)
      end

      test "recommends Business", %{conn: conn, site: site} do
        insert(:goal, site: site, currency: :USD, event_name: "Purchase")

        {:ok, _lv, doc} = get_liveview(conn)

        refute element_exists?(doc, @starter_highlight_pill)
        assert text_of_element(doc, @business_highlight_pill) == "Recommended"
        refute element_exists?(doc, @growth_highlight_pill)
      end

      test "recommends Business when pending ownership site used a premium feature", %{
        conn: conn,
        user: user
      } do
        previous_owner = new_user()
        site = new_site(owner: previous_owner)

        insert(:goal, site: site, currency: :USD, event_name: "Purchase")

        invite_transfer(site, user, inviter: previous_owner)

        {:ok, _lv, doc} = get_liveview(conn)

        assert text_of_element(doc, @business_highlight_pill) == "Recommended"
        refute element_exists?(doc, @growth_highlight_pill)
      end

      test "recommends Business when team member limit for Growth exceeded due to pending ownerships",
           %{conn: conn, user: user} do
        owned_site = new_site(owner: user)
        add_guest(owned_site, role: :editor)
        add_guest(owned_site, role: :editor)

        previous_owner = new_user()

        pending_ownership_site = new_site(owner: previous_owner)
        add_guest(pending_ownership_site, role: :viewer)

        invite_transfer(pending_ownership_site, user, inviter: previous_owner)

        {:ok, _lv, doc} = get_liveview(conn)

        assert text_of_element(doc, @business_highlight_pill) == "Recommended"
        refute element_exists?(doc, @growth_highlight_pill)
      end

      test "recommends Business when Growth site limit exceeded due to a pending ownership", %{
        conn: conn,
        user: user
      } do
        for _ <- 1..2, do: new_site(owner: user)
        assert user |> team_of() |> Plausible.Teams.Billing.site_usage() == 3

        another_user = new_user()
        pending_ownership_site = new_site(owner: another_user)

        invite_transfer(pending_ownership_site, user, inviter: another_user)

        {:ok, _lv, doc} = get_liveview(conn)

        assert text_of_element(doc, @business_highlight_pill) == "Recommended"
        refute element_exists?(doc, @growth_highlight_pill)
      end

      @tag :slow
      test "allows upgrade to a 100k plan with a pageview allowance margin of 0.15 when trial is active",
           %{conn: conn, site: site, user: user} do
        {:ok, team} = Plausible.Teams.get_or_create(user)

        new_trial_expiry_date =
          Plausible.Teams.Billing.starter_tier_launch() |> Date.shift(day: 31)

        # NOTE: This is temporary, making sure that the trial is treated as active,
        # but at the same time, ineligible for seeing the old upgrade page.
        Ecto.Changeset.change(team, %{trial_expiry_date: new_trial_expiry_date})
        |> Repo.update!()

        generate_usage_for(site, 115_000)

        {:ok, lv, _doc} = get_liveview(conn)
        doc = set_slider(lv, "100k")

        refute class_of_element(doc, @starter_checkout_button) =~ "pointer-events-none"
        refute class_of_element(doc, @growth_checkout_button) =~ "pointer-events-none"
        refute class_of_element(doc, @business_checkout_button) =~ "pointer-events-none"
        refute element_exists?(doc, @growth_plan_tooltip)

        generate_usage_for(site, 1)

        {:ok, lv, _doc} = get_liveview(conn)
        doc = set_slider(lv, "100k")

        assert class_of_element(doc, @starter_checkout_button) =~ "pointer-events-none"
        assert class_of_element(doc, @growth_checkout_button) =~ "pointer-events-none"
        assert class_of_element(doc, @business_checkout_button) =~ "pointer-events-none"

        assert text_of_element(doc, @growth_plan_tooltip) ==
                 "Your usage exceeds the following limit(s): Monthly pageview limit"
      end

      test "allows upgrade to a 10k plan with a pageview allowance margin of 0.3 when trial ended 10 days ago",
           %{conn: conn, site: site, user: user} do
        team =
          user
          |> team_of()
          |> Ecto.Changeset.change(trial_expiry_date: Date.shift(Date.utc_today(), day: -10))
          |> Repo.update!()

        generate_usage_for(site, 13_000)

        {:ok, lv, _doc} = get_liveview(conn)
        doc = set_slider(lv, "10k")

        # NOTE: drop the else clause once Starter tier is live for a trial that ended recently
        if Plausible.Teams.Billing.show_new_upgrade_page?(team) do
          refute class_of_element(doc, @starter_checkout_button) =~ "pointer-events-none"
        else
          refute element_exists?(doc, @starter_plan_box)
        end

        refute class_of_element(doc, @growth_checkout_button) =~ "pointer-events-none"
        refute class_of_element(doc, @business_checkout_button) =~ "pointer-events-none"

        generate_usage_for(site, 1)

        {:ok, lv, _doc} = get_liveview(conn)
        doc = set_slider(lv, "10k")

        # NOTE: drop the else clause once Starter tier is live for a trial that ended recently
        if Plausible.Teams.Billing.show_new_upgrade_page?(team) do
          refute class_of_element(doc, @starter_checkout_button) =~ "pointer-events-none"
        else
          refute element_exists?(doc, @starter_plan_box)
        end

        assert class_of_element(doc, @growth_checkout_button) =~ "pointer-events-none"
        assert class_of_element(doc, @business_checkout_button) =~ "pointer-events-none"
      end

      test "pageview allowance margin on upgrade is 0.1 when trial ended more than 10 days ago",
           %{
             conn: conn,
             site: site,
             user: user
           } do
        user
        |> team_of()
        |> Ecto.Changeset.change(trial_expiry_date: Date.shift(Date.utc_today(), day: -11))
        |> Repo.update!()

        generate_usage_for(site, 11_000)

        {:ok, lv, _doc} = get_liveview(conn)
        doc = set_slider(lv, "10k")

        refute class_of_element(doc, @growth_checkout_button) =~ "pointer-events-none"
        refute class_of_element(doc, @business_checkout_button) =~ "pointer-events-none"

        generate_usage_for(site, 1)

        {:ok, lv, _doc} = get_liveview(conn)
        doc = set_slider(lv, "10k")

        assert class_of_element(doc, @growth_checkout_button) =~ "pointer-events-none"
        assert class_of_element(doc, @business_checkout_button) =~ "pointer-events-none"
      end
    end

    describe "for a user with an active v5 growth subscription plan" do
      setup [:create_user, :create_site, :log_in, :subscribe_v5_growth]

      test "displays basic page content", %{conn: conn} do
        {:ok, _lv, doc} = get_liveview(conn)

        assert doc =~ "Change your subscription plan"
        assert doc =~ "Any other questions?"
        assert doc =~ "What happens if I go over my monthly pageview limit?"
      end

      test "does not render any global notices", %{conn: conn} do
        {:ok, _lv, doc} = get_liveview(conn)
        check_notice_titles(doc, [])
      end

      test "displays plan benefits", %{conn: conn} do
        {:ok, _lv, doc} = get_liveview(conn)

        starter_box = text_of_element(doc, @starter_plan_box)
        growth_box = text_of_element(doc, @growth_plan_box)
        business_box = text_of_element(doc, @business_plan_box)
        enterprise_box = text_of_element(doc, @enterprise_plan_box)

        assert starter_box =~ "Intuitive, fast and privacy-friendly dashboard"
        assert starter_box =~ "Email/Slack reports"
        assert starter_box =~ "Google Analytics import"
        assert starter_box =~ "Goals and custom events"
        assert starter_box =~ "One site"
        assert starter_box =~ "3 years of data retention"

        assert growth_box =~ "Up to 3 team members"
        assert growth_box =~ "Up to 3 sites"
        assert growth_box =~ "Team Management"
        assert growth_box =~ "Shared Links"
        assert growth_box =~ "Shared Segments"

        assert business_box =~ "Everything in Growth"
        assert business_box =~ "Up to 10 team members"
        assert business_box =~ "Up to 10 sites"
        assert business_box =~ "Stats API (600 requests per hour)"
        assert business_box =~ "Looker Studio Connector"
        assert business_box =~ "Custom Properties"
        assert business_box =~ "Funnels"
        assert business_box =~ "Ecommerce revenue attribution"
        assert business_box =~ "5 years of data retention"

        refute business_box =~ "Goals and custom events"

        assert enterprise_box =~ "Everything in Business"
        assert enterprise_box =~ "10+ team members"
        assert enterprise_box =~ "10+ sites"
        assert enterprise_box =~ "600+ Stats API requests per hour"
        assert enterprise_box =~ "Sites API access for"
        assert enterprise_box =~ "Technical onboarding"
        assert enterprise_box =~ "Priority support"
        assert enterprise_box =~ "5+ years of data retention"

        assert text_of_attr(find(doc, "#{@enterprise_plan_box} p a"), "href") =~
                 "https://plausible.io/white-label-web-analytics"
      end

      test "displays usage in the last cycle", %{conn: conn, site: site} do
        yesterday = NaiveDateTime.utc_now() |> NaiveDateTime.add(-1, :day)

        populate_stats(site, [
          build(:pageview, timestamp: yesterday),
          build(:pageview, timestamp: yesterday)
        ])

        {:ok, _lv, doc} = get_liveview(conn)
        assert doc =~ "You have used"
        assert doc =~ "<b>2</b>"
        assert doc =~ "billable pageviews in the last billing cycle"
      end

      test "renders notice about pending ownerships and counts their usage", %{
        conn: conn,
        user: user,
        site: site
      } do
        yesterday = NaiveDateTime.utc_now() |> NaiveDateTime.add(-1, :day)

        populate_stats(site, [
          build(:pageview, timestamp: yesterday)
        ])

        another_user = new_user()

        pending_site = new_site(owner: another_user)
        add_guest(pending_site, role: :editor)
        add_guest(pending_site, role: :viewer)
        add_guest(pending_site, role: :viewer)

        populate_stats(pending_site, [
          build(:pageview, timestamp: yesterday)
        ])

        invite_transfer(pending_site, user, inviter: another_user)

        {:ok, _lv, doc} = get_liveview(conn)

        check_notice_titles(doc, [Billing.pending_site_ownerships_notice_title()])
        assert doc =~ "Your account has been invited to become the owner of a site"

        assert text_of_element(doc, @starter_plan_tooltip) =~
                 "Your usage exceeds the following limit(s):"

        assert text_of_element(doc, @starter_plan_tooltip) =~
                 "Team member limit"

        assert text_of_element(doc, @starter_plan_tooltip) =~
                 "Site limit"

        assert text_of_element(doc, @growth_plan_tooltip) ==
                 "Your usage exceeds the following limit(s): Team member limit"

        assert doc =~ "<b>2</b>"
        assert doc =~ "billable pageviews in the last billing cycle"
      end

      test "warns about losing access to a feature used by a pending ownership site and recommends business tier",
           %{
             conn: conn,
             user: user
           } do
        another_user = new_user()
        pending_site = new_site(owner: another_user)

        Plausible.Props.allow(pending_site, ["author"])

        invite_transfer(pending_site, user, inviter: another_user)

        {:ok, _lv, doc} = get_liveview(conn)

        assert doc =~ "Your account has been invited to become the owner of a site"

        assert text_of_attr(find(doc, @growth_checkout_button), "onclick") =~
                 "if (confirm(\"This plan does not support Custom Properties, which you have been using. By subscribing to this plan, you will not have access to this feature.\")) {window.location ="

        assert text_of_element(doc, @business_highlight_pill) == "Recommended"
        refute element_exists?(doc, @growth_highlight_pill)
      end

      test "gets default selected interval from current subscription plan", %{
        conn: conn,
        user: user
      } do
        {:ok, _lv, doc} = get_liveview(conn)
        assert class_of_element(doc, @yearly_interval_button) =~ @interval_button_active_class

        subscribe_to_plan(user, @v4_growth_10k_monthly_plan_id)

        {:ok, _lv, doc} = get_liveview(conn)
        assert class_of_element(doc, @monthly_interval_button) =~ @interval_button_active_class
      end

      test "sets pageview slider according to last cycle usage", %{conn: conn} do
        {:ok, _lv, doc} = get_liveview(conn)
        assert text_of_element(doc, @slider_value) == "10k"
      end

      test "pageview slider changes selected volume", %{conn: conn} do
        {:ok, lv, _doc} = get_liveview(conn)

        doc = set_slider(lv, "100k")
        assert text_of_element(doc, @slider_value) == "100k"

        doc = set_slider(lv, "10k")
        assert text_of_element(doc, @slider_value) == "10k"
      end

      test "makes it clear that the user is currently on a growth tier", %{conn: conn} do
        {:ok, _lv, doc} = get_liveview(conn)

        class = class_of_element(doc, @growth_plan_box)

        assert class =~ "ring-2"
        assert class =~ "ring-indigo-600"
        assert text_of_element(doc, @growth_highlight_pill) == "Current"
      end

      test "checkout button text and click-disabling CSS classes are dynamic", %{conn: conn} do
        {:ok, lv, _doc} = get_liveview(conn)

        doc = set_slider(lv, "200k")

        assert text_of_element(doc, @starter_checkout_button) == "Downgrade to Starter"
        assert text_of_element(doc, @growth_checkout_button) == "Currently on this plan"
        assert text_of_element(doc, @business_checkout_button) == "Upgrade to Business"

        assert class_of_element(doc, @growth_checkout_button) =~ "pointer-events-none bg-gray-400"

        doc = element(lv, @monthly_interval_button) |> render_click()

        assert text_of_element(doc, @starter_checkout_button) == "Downgrade to Starter"
        assert text_of_element(doc, @growth_checkout_button) == "Change billing interval"
        assert text_of_element(doc, @business_checkout_button) == "Upgrade to Business"

        doc = set_slider(lv, "1M")

        assert text_of_element(doc, @starter_checkout_button) == "Downgrade to Starter"
        assert text_of_element(doc, @growth_checkout_button) == "Upgrade"
        assert text_of_element(doc, @business_checkout_button) == "Upgrade to Business"

        doc = set_slider(lv, "100k")

        assert text_of_element(doc, @starter_checkout_button) == "Downgrade to Starter"
        assert text_of_element(doc, @growth_checkout_button) == "Downgrade"
        assert text_of_element(doc, @business_checkout_button) == "Upgrade to Business"
      end

      test "checkout buttons are dynamic links to /billing/change-plan/preview/<plan_id>", %{
        conn: conn
      } do
        {:ok, lv, doc} = get_liveview(conn)

        growth_checkout_button = find(doc, @growth_checkout_button)

        assert text_of_attr(growth_checkout_button, "onclick") =~
                 "if (true) {window.location = '#{Routes.billing_path(conn, :change_plan_preview, @v5_growth_10k_yearly_plan_id)}'}"

        set_slider(lv, "5M")
        doc = element(lv, @monthly_interval_button) |> render_click()

        starter_checkout_button = find(doc, @starter_checkout_button)

        assert text_of_attr(starter_checkout_button, "onclick") =~
                 "if (true) {window.location = '#{Routes.billing_path(conn, :change_plan_preview, @v5_starter_5m_monthly_plan_id)}'}"

        business_checkout_button = find(doc, @business_checkout_button)

        assert text_of_attr(business_checkout_button, "onclick") =~
                 "if (true) {window.location = '#{Routes.billing_path(conn, :change_plan_preview, @v5_business_5m_monthly_plan_id)}'}"
      end
    end

    describe "for a user with an active v4 business subscription plan" do
      setup [:create_user, :create_site, :log_in, :subscribe_v4_business]

      test "sets pageview slider according to last cycle usage", %{conn: conn} do
        {:ok, _lv, doc} = get_liveview(conn)
        assert text_of_element(doc, @slider_value) == "10k"
      end

      test "does not render any global notices", %{conn: conn} do
        {:ok, _lv, doc} = get_liveview(conn)
        check_notice_titles(doc, [])
      end

      test "highlights Business box as the 'Current' tier", %{
        conn: conn,
        site: site
      } do
        insert(:goal, site: site, currency: :USD, event_name: "Purchase")

        {:ok, _lv, doc} = get_liveview(conn)

        class = class_of_element(doc, @business_plan_box)

        assert class =~ "ring-2"
        assert class =~ "ring-indigo-600"
        assert text_of_element(doc, @business_highlight_pill) == "Current"

        refute element_exists?(doc, @starter_highlight_pill)
        refute element_exists?(doc, @growth_highlight_pill)
      end

      test "recommends Enterprise when site limit exceeds Business tier due to pending ownerships",
           %{
             conn: conn,
             user: user
           } do
        team = team_of(user)

        for _ <- 1..49 do
          new_site(owner: user)
        end

        assert 50 = Plausible.Teams.Billing.quota_usage(team).sites

        another_user = new_user()
        pending_ownership_site = new_site(owner: another_user)

        invite_transfer(pending_ownership_site, user, inviter: another_user)

        {:ok, _lv, doc} = get_liveview(conn)

        assert text_of_element(doc, @enterprise_highlight_pill) == "Recommended"
        refute element_exists?(doc, @starter_highlight_pill)
        refute element_exists?(doc, @business_highlight_pill)
        refute element_exists?(doc, @growth_highlight_pill)
      end

      test "checkout button text and click-disabling CSS classes are dynamic", %{conn: conn} do
        {:ok, lv, _doc} = get_liveview(conn)

        doc = set_slider(lv, "5M")

        assert text_of_element(doc, @starter_checkout_button) == "Downgrade to Starter"
        assert text_of_element(doc, @growth_checkout_button) == "Downgrade to Growth"
        assert text_of_element(doc, @business_checkout_button) == "Currently on this plan"

        assert class_of_element(doc, @business_checkout_button) =~
                 "pointer-events-none bg-gray-400"

        doc = element(lv, @yearly_interval_button) |> render_click()

        assert text_of_element(doc, @starter_checkout_button) == "Downgrade to Starter"
        assert text_of_element(doc, @growth_checkout_button) == "Downgrade to Growth"
        assert text_of_element(doc, @business_checkout_button) == "Change billing interval"

        doc = set_slider(lv, "10M")

        assert text_of_element(doc, @starter_checkout_button) == "Downgrade to Starter"
        assert text_of_element(doc, @growth_checkout_button) == "Downgrade to Growth"
        assert text_of_element(doc, @business_checkout_button) == "Upgrade"

        doc = set_slider(lv, "100k")

        assert text_of_element(doc, @starter_checkout_button) == "Downgrade to Starter"
        assert text_of_element(doc, @growth_checkout_button) == "Downgrade to Growth"
        assert text_of_element(doc, @business_checkout_button) == "Downgrade"
      end

      test "checkout is disabled when team member usage exceeds rendered plan limit", %{
        conn: conn,
        site: site
      } do
        for _ <- 1..4, do: add_guest(site, role: :viewer)

        {:ok, _lv, doc} = get_liveview(conn)

        assert text_of_element(doc, @starter_plan_box) =~ "Your usage exceeds this plan"
        assert class_of_element(doc, @starter_checkout_button) =~ "pointer-events-none"

        assert text_of_element(doc, @starter_plan_tooltip) ==
                 "Your usage exceeds the following limit(s): Team member limit"

        assert text_of_element(doc, @growth_plan_box) =~ "Your usage exceeds this plan"
        assert class_of_element(doc, @growth_checkout_button) =~ "pointer-events-none"

        assert text_of_element(doc, @growth_plan_tooltip) ==
                 "Your usage exceeds the following limit(s): Team member limit"
      end

      test "checkout is disabled when sites usage exceeds rendered plan limit", %{
        conn: conn,
        user: user
      } do
        for _ <- 1..11, do: new_site(owner: user)

        {:ok, _lv, doc} = get_liveview(conn)

        assert text_of_element(doc, @starter_plan_box) =~ "Your usage exceeds this plan"
        assert class_of_element(doc, @starter_checkout_button) =~ "pointer-events-none"

        assert text_of_element(doc, @starter_plan_tooltip) ==
                 "Your usage exceeds the following limit(s): Site limit"

        assert text_of_element(doc, @growth_plan_box) =~ "Your usage exceeds this plan"
        assert class_of_element(doc, @growth_checkout_button) =~ "pointer-events-none"

        assert text_of_element(doc, @growth_plan_tooltip) ==
                 "Your usage exceeds the following limit(s): Site limit"
      end

      test "when more than one limit is exceeded, the tooltip enumerates them", %{
        conn: conn,
        user: user
      } do
        for _ <- 1..11, do: new_site(owner: user)

        site = new_site(owner: user)
        for _ <- 1..4, do: add_guest(site, role: :viewer)

        {:ok, _lv, doc} = get_liveview(conn)

        assert text_of_element(doc, @starter_plan_tooltip) =~ "Team member limit"
        assert text_of_element(doc, @starter_plan_tooltip) =~ "Site limit"

        assert text_of_element(doc, @growth_plan_tooltip) =~ "Team member limit"
        assert text_of_element(doc, @growth_plan_tooltip) =~ "Site limit"
      end

      test "checkout is not disabled when pageview usage exceeded but next upgrade allowed by override",
           %{
             conn: conn,
             user: user,
             site: site
           } do
        now = NaiveDateTime.utc_now()

        generate_usage_for(site, 11_000, Timex.shift(now, days: -5))
        generate_usage_for(site, 11_000, Timex.shift(now, days: -35))

        user
        |> team_of()
        |> Ecto.Changeset.change(allow_next_upgrade_override: true)
        |> Plausible.Repo.update!()

        {:ok, lv, _doc} = get_liveview(conn)

        doc = set_slider(lv, "10k")

        refute text_of_element(doc, @growth_plan_box) =~ "Your usage exceeds this plan"
        refute class_of_element(doc, @growth_checkout_button) =~ "pointer-events-none"
      end

      test "warns about losing access to a feature", %{conn: conn, user: user, site: site} do
        Plausible.Props.allow(site, ["author"])
        insert(:goal, currency: :USD, site: site, event_name: "Purchase")
        insert(:api_key, user: user)

        {:ok, _lv, doc} = get_liveview(conn)

        assert text_of_attr(find(doc, @growth_checkout_button), "onclick") =~
                 "if (confirm(\"This plan does not support Custom Properties, Revenue Goals and Stats API, which you have been using. By subscribing to this plan, you will not have access to these features.\")) {window.location = "
      end
    end

    describe "for a user with a v3 business (unlimited team members) subscription plan" do
      setup [:create_user, :create_site, :log_in]

      setup %{user: user} = context do
        create_subscription_for(user, paddle_plan_id: @v3_business_10k_monthly_plan_id)
        {:ok, context}
      end

      test "does not render any global notices", %{conn: conn} do
        {:ok, _lv, doc} = get_liveview(conn)
        check_notice_titles(doc, [])
      end

      test "displays plan benefits", %{conn: conn} do
        {:ok, _lv, doc} = get_liveview(conn)

        starter_box = text_of_element(doc, @starter_plan_box)
        growth_box = text_of_element(doc, @growth_plan_box)
        business_box = text_of_element(doc, @business_plan_box)
        enterprise_box = text_of_element(doc, @enterprise_plan_box)

        assert starter_box =~ "Intuitive, fast and privacy-friendly dashboard"
        assert starter_box =~ "Email/Slack reports"
        assert starter_box =~ "Google Analytics import"
        assert starter_box =~ "Goals and custom events"
        assert starter_box =~ "One site"
        assert starter_box =~ "3 years of data retention"

        assert growth_box =~ "Up to 3 team members"
        assert growth_box =~ "Up to 3 sites"
        assert growth_box =~ "Team Management"
        assert growth_box =~ "Shared Links"
        assert growth_box =~ "Shared Segments"

        assert business_box =~ "Everything in Growth"
        assert business_box =~ "Unlimited team members"
        assert business_box =~ "Up to 50 sites"
        assert business_box =~ "Stats API (600 requests per hour)"
        assert business_box =~ "Looker Studio Connector"
        assert business_box =~ "Custom Properties"
        assert business_box =~ "Funnels"
        assert business_box =~ "Ecommerce revenue attribution"

        refute business_box =~ "Goals and custom events"

        assert enterprise_box =~ "Everything in Business"
        assert enterprise_box =~ "50+ sites"
        assert enterprise_box =~ "600+ Stats API requests per hour"
        assert enterprise_box =~ "Sites API access for"
        assert enterprise_box =~ "Technical onboarding"
        assert enterprise_box =~ "Priority support"

        refute enterprise_box =~ "team members"

        assert text_of_attr(find(doc, "#{@enterprise_plan_box} p a"), "href") =~
                 "https://plausible.io/white-label-web-analytics"
      end
    end

    describe "for a user with a past_due subscription" do
      setup [:create_user, :create_site, :log_in, :create_past_due_subscription]

      test "renders failed payment notice and link to update billing details", %{conn: conn} do
        {:ok, _lv, doc} = get_liveview(conn)
        check_notice_titles(doc, [Billing.subscription_past_due_notice_title()])
        assert doc =~ "There was a problem with your latest payment"
        assert doc =~ "https://update.billing.details"
      end

      test "checkout buttons are disabled + notice about billing details (unless plan owned already)",
           %{conn: conn} do
        {:ok, lv, _doc} = get_liveview(conn)

        doc = set_slider(lv, "200k")

        assert class_of_element(doc, @growth_checkout_button) =~ "pointer-events-none bg-gray-400"
        assert text_of_element(doc, @growth_checkout_button) =~ "Currently on this plan"
        refute element_exists?(doc, "#{@growth_checkout_button} + div")

        assert class_of_element(doc, @business_checkout_button) =~
                 "pointer-events-none bg-gray-400"

        assert text_of_element(doc, "#{@business_checkout_button} + div") =~
                 "Please update your billing details first"

        doc = set_slider(lv, "1M")

        assert class_of_element(doc, @growth_checkout_button) =~ "pointer-events-none bg-gray-400"

        assert text_of_element(doc, "#{@growth_checkout_button} + div") =~
                 "Please update your billing details first"
      end
    end

    describe "for a user with a paused v4 subscription" do
      setup [:create_user, :create_site, :log_in, :create_paused_subscription]

      test "renders subscription paused notice and link to update billing details", %{conn: conn} do
        {:ok, _lv, doc} = get_liveview(conn)
        check_notice_titles(doc, [Billing.subscription_paused_notice_title()])
        assert doc =~ "Your subscription is paused due to failed payments"
        assert doc =~ "https://update.billing.details"
      end

      test "checkout buttons are disabled + notice about billing details when plan not owned already",
           %{conn: conn} do
        {:ok, lv, _doc} = get_liveview(conn)

        doc = set_slider(lv, "200k")

        assert class_of_element(doc, @growth_checkout_button) =~ "pointer-events-none bg-gray-400"
        assert text_of_element(doc, @growth_checkout_button) =~ "Currently on this plan"
        refute element_exists?(doc, "#{@growth_checkout_button} + div")

        assert class_of_element(doc, @business_checkout_button) =~
                 "pointer-events-none bg-gray-400"

        assert text_of_element(doc, "#{@business_checkout_button} + div") =~
                 "Please update your billing details first"

        doc = set_slider(lv, "1M")

        assert class_of_element(doc, @growth_checkout_button) =~ "pointer-events-none bg-gray-400"

        assert text_of_element(doc, "#{@growth_checkout_button} + div") =~
                 "Please update your billing details first"
      end
    end

    describe "for a user with a cancelled, but still active v4 subscription" do
      setup [:create_user, :create_site, :log_in, :create_cancelled_subscription]

      test "does not render any global notices", %{conn: conn} do
        {:ok, _lv, doc} = get_liveview(conn)
        check_notice_titles(doc, [])
      end

      test "checkout buttons are paddle buttons", %{conn: conn} do
        {:ok, _lv, doc} = get_liveview(conn)

        assert text_of_attr(find(doc, @growth_checkout_button), "onclick") =~
                 "Paddle.Checkout.open"

        assert text_of_attr(find(doc, @business_checkout_button), "onclick") =~
                 "Paddle.Checkout.open"
      end

      test "currently owned tier is highlighted", %{conn: conn} do
        {:ok, _lv, doc} = get_liveview(conn)
        assert text_of_element(doc, @growth_highlight_pill) == "Current"
      end

      test "can subscribe again to the currently owned (but cancelled) plan", %{conn: conn} do
        {:ok, _lv, doc} = get_liveview(conn)
        refute class_of_element(doc, @growth_checkout_button) =~ "pointer-events-none"
      end
    end

    describe "for a user with a cancelled and expired subscription" do
      setup [:create_user, :create_site, :log_in, :create_cancelled_subscription]

      setup %{user: user} do
        user
        |> team_of()
        |> Repo.preload(:subscription)
        |> Map.fetch!(:subscription)
        |> Subscription.changeset(%{next_bill_date: Timex.shift(Timex.now(), months: -2)})
        |> Repo.update!()

        :ok
      end

      test "does not render any global notices", %{conn: conn} do
        {:ok, _lv, doc} = get_liveview(conn)
        check_notice_titles(doc, [])
      end

      test "highlights recommended tier", %{conn: conn} do
        {:ok, _lv, doc} = get_liveview(conn)
        assert text_of_element(doc, @starter_highlight_pill) == "Recommended"
        refute element_exists?(doc, @growth_highlight_pill)
        refute element_exists?(doc, @business_highlight_pill)
      end
    end

    describe "for a grandfathered user with a high volume plan" do
      setup [:create_user, :create_site, :log_in]

      test "does not render any global notices", %{conn: conn, user: user} do
        create_subscription_for(user, paddle_plan_id: @v1_50m_yearly_plan_id)
        {:ok, _lv, doc} = get_liveview(conn)
        check_notice_titles(doc, [])
      end

      test "on a 50M v1 plan, Starter plans are not rendered, Growth plans are available at 20M, 50M, 50M+, and Business plans are up to 10M",
           %{conn: conn, user: user} do
        create_subscription_for(user, paddle_plan_id: @v1_50m_yearly_plan_id)

        {:ok, lv, doc} = get_liveview(conn)

        refute element_exists?(doc, @starter_plan_box)

        doc = set_slider(lv, 8)
        assert text_of_element(doc, @slider_value) == "20M"
        assert text_of_element(doc, @business_plan_box) =~ "Contact us"
        assert text_of_element(doc, @growth_price_tag_amount) == "€1,800"
        assert text_of_element(doc, @growth_price_tag_interval) == "/year"

        doc = set_slider(lv, 9)
        assert text_of_element(doc, @slider_value) == "50M"
        assert text_of_element(doc, @business_plan_box) =~ "Contact us"
        assert text_of_element(doc, @growth_price_tag_amount) == "€2,640"
        assert text_of_element(doc, @growth_price_tag_interval) == "/year"

        doc = set_slider(lv, 10)
        assert text_of_element(doc, @slider_value) == "50M+"
        assert text_of_element(doc, @business_plan_box) =~ "Contact us"
        assert text_of_element(doc, @growth_plan_box) =~ "Contact us"

        doc = set_slider(lv, 7)
        assert text_of_element(doc, @slider_value) == "10M"
        refute text_of_element(doc, @business_plan_box) =~ "Contact us"
        refute text_of_element(doc, @growth_plan_box) =~ "Contact us"
      end

      test "on a 20M v2 plan, Growth tiers are available at 20M and 20M+, but not 50M",
           %{conn: conn, user: user} do
        create_subscription_for(user, paddle_plan_id: @v2_20m_yearly_plan_id)

        {:ok, lv, _doc} = get_liveview(conn)

        doc = set_slider(lv, 8)
        assert text_of_element(doc, @slider_value) == "20M"
        assert text_of_element(doc, @growth_price_tag_amount) == "€2,250"
        assert text_of_element(doc, @growth_price_tag_interval) == "/year"

        doc = set_slider(lv, 9)
        assert text_of_element(doc, @slider_value) == "20M+"
        assert text_of_element(doc, @growth_plan_box) =~ "Contact us"
      end
    end

    describe "for a grandfathered user on a v1 10k plan" do
      setup [:create_user, :create_site, :log_in]

      setup %{user: user} = context do
        create_subscription_for(user, paddle_plan_id: @v1_10k_yearly_plan_id)
        {:ok, context}
      end

      test "does not render any global notices", %{conn: conn} do
        {:ok, _lv, doc} = get_liveview(conn)
        check_notice_titles(doc, [])
      end

      test "v1 20M and 50M Growth plans are not available",
           %{conn: conn} do
        {:ok, lv, _doc} = get_liveview(conn)

        doc = set_slider(lv, 8)
        assert text_of_element(doc, @slider_value) == "10M+"
        assert text_of_element(doc, @growth_plan_box) =~ "Contact us"
      end

      test "displays plan benefits", %{conn: conn} do
        {:ok, _lv, doc} = get_liveview(conn)

        refute element_exists?(doc, @starter_plan_box)
        growth_box = text_of_element(doc, @growth_plan_box)
        business_box = text_of_element(doc, @business_plan_box)
        enterprise_box = text_of_element(doc, @enterprise_plan_box)

        assert growth_box =~ "Up to 50 sites"
        assert growth_box =~ "Unlimited team members"
        assert growth_box =~ "Team Management"
        assert growth_box =~ "Saved Segments"
        assert growth_box =~ "Goals and custom events"
        assert growth_box =~ "Custom Properties"
        assert growth_box =~ "Stats API (600 requests per hour)"
        assert growth_box =~ "Looker Studio Connector"
        assert growth_box =~ "Shared Links"
        assert growth_box =~ "Embedded Dashboards"

        assert business_box =~ "Everything in Growth"
        assert business_box =~ "Funnels"
        assert business_box =~ "Ecommerce revenue attribution"

        refute business_box =~ "Goals and custom events"
        refute business_box =~ "Unlimited team members"
        refute business_box =~ "Up to 50 sites"
        refute business_box =~ "Stats API (600 requests per hour)"
        refute business_box =~ "Looker Studio Connector"
        refute business_box =~ "Custom Properties"

        assert enterprise_box =~ "Everything in Business"
        assert enterprise_box =~ "50+ sites"
        assert enterprise_box =~ "600+ Stats API requests per hour"
        assert enterprise_box =~ "Sites API access for"
        assert enterprise_box =~ "Technical onboarding"
        assert enterprise_box =~ "Priority support"

        assert text_of_attr(find(doc, "#{@enterprise_plan_box} p a"), "href") =~
                 "https://plausible.io/white-label-web-analytics"

        refute enterprise_box =~ "10+ team members"
        refute enterprise_box =~ "Unlimited team members"
      end
    end

    describe "for a user without a trial_expiry_date (invited user) who owns a site (transferred)" do
      setup [:create_user, :create_site, :log_in]

      setup %{user: user} do
        user
        |> team_of()
        |> Ecto.Changeset.change(trial_expiry_date: nil)
        |> Repo.update!()

        :ok
      end

      test "does not render any global notices", %{conn: conn} do
        {:ok, _lv, doc} = get_liveview(conn)
        check_notice_titles(doc, [])
      end

      test "allows to upgrade", %{conn: conn} do
        {:ok, lv, _doc} = get_liveview(conn)
        doc = set_slider(lv, "100k")

        refute class_of_element(doc, @starter_checkout_button) =~ "pointer-events-none"
        refute class_of_element(doc, @growth_checkout_button) =~ "pointer-events-none"
        refute class_of_element(doc, @business_checkout_button) =~ "pointer-events-none"
      end
    end

    describe "for a free_10k subscription" do
      setup [:create_user, :create_site, :log_in, :subscribe_free_10k]

      test "recommends starter tier", %{conn: conn} do
        {:ok, _lv, doc} = get_liveview(conn)
        assert element_exists?(doc, @starter_highlight_pill)
        refute element_exists?(doc, @growth_highlight_pill)
        refute element_exists?(doc, @business_highlight_pill)
      end

      test "recommends Business tier when premium features used", %{conn: conn, site: site} do
        insert(:goal, currency: :USD, site: site, event_name: "Purchase")

        {:ok, _lv, doc} = get_liveview(conn)

        assert text_of_element(doc, @business_plan_box) =~ "Recommended"
        refute text_of_element(doc, @growth_plan_box) =~ "Recommended"
        refute text_of_element(doc, @starter_plan_box) =~ "Recommended"
      end

      test "renders Paddle upgrade buttons", %{conn: conn, user: user} do
        {:ok, lv, _doc} = get_liveview(conn)
        {:ok, team} = Plausible.Teams.get_by_owner(user)

        set_slider(lv, "200k")
        doc = element(lv, @yearly_interval_button) |> render_click()

        assert %{
                 "disableLogout" => true,
                 "email" => user.email,
                 "passthrough" => "ee:true;user:#{user.id};team:#{team.id}",
                 "product" => @v5_growth_200k_yearly_plan_id,
                 "success" => Routes.billing_path(PlausibleWeb.Endpoint, :upgrade_success),
                 "theme" => "none"
               } == get_paddle_checkout_params(find(doc, @growth_checkout_button))
      end
    end

    describe "for a user with no sites" do
      setup [:create_user, :log_in]

      test "does not allow to subscribe and renders notice", %{conn: conn} do
        {:ok, _lv, doc} = get_liveview(conn)

        check_notice_titles(doc, [Billing.upgrade_ineligible_notice_title()])

        assert text_of_element(doc, "#upgrade-eligible-notice") =~
                 "You cannot start a subscription"

        assert class_of_element(doc, @starter_checkout_button) =~ "pointer-events-none"
        assert class_of_element(doc, @growth_checkout_button) =~ "pointer-events-none"
        assert class_of_element(doc, @business_checkout_button) =~ "pointer-events-none"
      end
    end

    describe "for a user with no sites but pending ownership transfer" do
      setup [:create_user, :log_in]

      setup %{user: user} do
        old_owner = new_user()
        site = new_site(owner: old_owner)
        invite_transfer(site, user, inviter: old_owner)

        :ok
      end

      test "renders only the pending ownership transfer notice", %{conn: conn} do
        {:ok, _lv, doc} = get_liveview(conn)
        check_notice_titles(doc, [Billing.pending_site_ownerships_notice_title()])
      end

      test "allows to subscribe", %{conn: conn} do
        {:ok, _lv, doc} = get_liveview(conn)

        assert text_of_element(doc, @starter_plan_box) =~ "Recommended"
        refute class_of_element(doc, @growth_checkout_button) =~ "pointer-events-none"
        refute class_of_element(doc, @business_checkout_button) =~ "pointer-events-none"
      end
    end

    # Checks the given HTML document for the presence of all possible billing
    # notices. For those expected, we assert that only one is present. Others
    # should not appear in the document.
    defp check_notice_titles(doc, expected) do
      [
        Billing.dashboard_locked_notice_title(),
        Billing.active_grace_period_notice_title(),
        Billing.subscription_cancelled_notice_title(),
        Billing.subscription_past_due_notice_title(),
        Billing.subscription_paused_notice_title(),
        Billing.upgrade_ineligible_notice_title(),
        Billing.pending_site_ownerships_notice_title()
      ]
      |> Enum.each(fn title ->
        if title in expected do
          assert length(String.split(doc, title)) == 2
        else
          refute doc =~ title
        end
      end)
    end

    defp subscribe_v5_growth(%{user: user}) do
      create_subscription_for(user, paddle_plan_id: @v5_growth_200k_yearly_plan_id)
    end

    defp subscribe_v4_business(%{user: user}) do
      create_subscription_for(user, paddle_plan_id: @v4_business_5m_monthly_plan_id)
    end

    defp create_past_due_subscription(%{user: user}) do
      create_subscription_for(user,
        paddle_plan_id: @v4_growth_200k_yearly_plan_id,
        status: Subscription.Status.past_due(),
        update_url: "https://update.billing.details"
      )
    end

    defp create_paused_subscription(%{user: user}) do
      create_subscription_for(user,
        paddle_plan_id: @v4_growth_200k_yearly_plan_id,
        status: Subscription.Status.paused(),
        update_url: "https://update.billing.details"
      )
    end

    defp create_cancelled_subscription(%{user: user}) do
      create_subscription_for(user,
        paddle_plan_id: @v4_growth_200k_yearly_plan_id,
        status: Subscription.Status.deleted()
      )
    end

    defp create_subscription_for(user, subscription_opts) do
      {paddle_plan_id, subscription_opts} = Keyword.pop(subscription_opts, :paddle_plan_id)

      user =
        subscribe_to_plan(user, paddle_plan_id, subscription_opts)

      {:ok, user: user}
    end

    defp subscribe_free_10k(%{user: user}) do
      user = subscribe_to_plan(user, "free_10k")
      {:ok, user: user}
    end

    defp get_liveview(conn) do
      conn = assign(conn, :live_module, PlausibleWeb.Live.ChoosePlan)
      {:ok, _lv, _doc} = live(conn, Routes.billing_path(conn, :choose_plan))
    end

    defp get_paddle_checkout_params(element) do
      with onclick <- text_of_attr(element, "onclick"),
           [[_, checkout_params_str]] <- Regex.scan(~r/Paddle\.Checkout\.open\((.*?)\)/, onclick),
           {:ok, checkout_params} <- Jason.decode(checkout_params_str) do
        checkout_params
      end
    end

    defp set_slider(lv, volume) when is_binary(volume) do
      index = Enum.find_index(@slider_volumes, &(&1 == volume))
      set_slider(lv, index)
    end

    defp set_slider(lv, index) do
      lv
      |> element(@slider_input)
      |> render_change(%{slider: index})
    end
  end
end
