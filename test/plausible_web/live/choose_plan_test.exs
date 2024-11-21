defmodule PlausibleWeb.Live.ChoosePlanTest do
  use PlausibleWeb.ConnCase, async: true
  use Plausible.Teams.Test
  @moduletag :ee_only

  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML
  require Plausible.Billing.Subscription.Status
  alias Plausible.{Repo, Billing.Subscription}

  @v1_10k_yearly_plan_id "572810"
  @v1_50m_yearly_plan_id "650653"
  @v2_20m_yearly_plan_id "653258"
  @v4_growth_10k_yearly_plan_id "857079"
  @v4_growth_200k_yearly_plan_id "857081"
  @v4_business_5m_monthly_plan_id "857111"
  @v3_business_10k_monthly_plan_id "857481"

  @monthly_interval_button ~s/label[phx-click="set_interval"][phx-value-interval="monthly"]/
  @yearly_interval_button ~s/label[phx-click="set_interval"][phx-value-interval="yearly"]/
  @interval_button_active_class "bg-indigo-600 text-white"
  @slider_input ~s/input[name="slider"]/
  @slider_value "#slider-value"

  @growth_plan_box "#growth-plan-box"
  @growth_plan_tooltip "#growth-plan-box .tooltip-content"
  @growth_price_tag_amount "#growth-price-tag-amount"
  @growth_price_tag_interval "#growth-price-tag-interval"
  @growth_highlight_pill "#{@growth_plan_box} #highlight-pill"
  @growth_checkout_button "#growth-checkout"

  @business_plan_box "#business-plan-box"
  @business_price_tag_amount "#business-price-tag-amount"
  @business_price_tag_interval "#business-price-tag-interval"
  @business_highlight_pill "#{@business_plan_box} #highlight-pill"
  @business_checkout_button "#business-checkout"

  @enterprise_plan_box "#enterprise-plan-box"
  @enterprise_highlight_pill "#enterprise-highlight-pill"

  @slider_volumes ["10k", "100k", "200k", "500k", "1M", "2M", "5M", "10M", "10M+"]

  describe "for a user with no subscription" do
    setup [:create_user, :create_site, :log_in]

    test "displays basic page content", %{conn: conn} do
      {:ok, _lv, doc} = get_liveview(conn)

      assert doc =~ "Upgrade your account"
      assert doc =~ "You have used"
      assert doc =~ "<b>0</b>"
      assert doc =~ "billable pageviews in the last 30 days"
      assert doc =~ "Questions?"
      assert doc =~ "What happens if I go over my page views limit?"
      assert doc =~ "Enterprise"
      assert doc =~ "+ VAT if applicable"
    end

    test "displays plan benefits", %{conn: conn} do
      {:ok, _lv, doc} = get_liveview(conn)

      growth_box = text_of_element(doc, @growth_plan_box)
      business_box = text_of_element(doc, @business_plan_box)
      enterprise_box = text_of_element(doc, @enterprise_plan_box)

      assert growth_box =~ "Up to 3 team members"
      assert growth_box =~ "Up to 10 sites"
      assert growth_box =~ "Intuitive, fast and privacy-friendly dashboard"
      assert growth_box =~ "Email/Slack reports"
      assert growth_box =~ "Google Analytics import"
      assert growth_box =~ "Goals and custom events"

      assert business_box =~ "Everything in Growth"
      assert business_box =~ "Up to 10 team members"
      assert business_box =~ "Up to 50 sites"
      assert business_box =~ "Stats API (600 requests per hour)"
      assert business_box =~ "Custom Properties"
      assert business_box =~ "Funnels"
      assert business_box =~ "Ecommerce revenue attribution"
      assert business_box =~ "Priority support"

      refute business_box =~ "Goals and custom events"

      assert enterprise_box =~ "Everything in Business"
      assert enterprise_box =~ "10+ team members"
      assert enterprise_box =~ "50+ sites"
      assert enterprise_box =~ "600+ Stats API requests per hour"
      assert enterprise_box =~ "Sites API access for"
      assert enterprise_box =~ "Technical onboarding"

      assert text_of_attr(find(doc, "#{@enterprise_plan_box} p a"), "href") =~
               "https://plausible.io/white-label-web-analytics"
    end

    test "default billing interval is monthly, and can switch to yearly", %{conn: conn} do
      {:ok, lv, doc} = get_liveview(conn)

      assert class_of_element(doc, @monthly_interval_button) =~ @interval_button_active_class
      refute class_of_element(doc, @yearly_interval_button) =~ @interval_button_active_class

      doc = element(lv, @yearly_interval_button) |> render_click()

      refute class_of_element(doc, @monthly_interval_button) =~ @interval_button_active_class
      assert class_of_element(doc, @yearly_interval_button) =~ @interval_button_active_class
    end

    test "default pageview limit is 10k", %{conn: conn} do
      {:ok, _lv, doc} = get_liveview(conn)
      assert text_of_element(doc, @slider_value) == "10k"
      assert text_of_element(doc, @growth_price_tag_amount) == "€10"
      assert text_of_element(doc, @business_price_tag_amount) == "€90"
    end

    test "pageview slider changes selected volume and prices shown", %{conn: conn} do
      {:ok, lv, _doc} = get_liveview(conn)

      doc = set_slider(lv, "100k")
      assert text_of_element(doc, @slider_value) == "100k"
      assert text_of_element(doc, @growth_price_tag_amount) == "€20"
      assert text_of_element(doc, @business_price_tag_amount) == "€100"

      doc = set_slider(lv, "200k")
      assert text_of_element(doc, @slider_value) == "200k"
      assert text_of_element(doc, @growth_price_tag_amount) == "€30"
      assert text_of_element(doc, @business_price_tag_amount) == "€110"

      doc = set_slider(lv, "500k")
      assert text_of_element(doc, @slider_value) == "500k"
      assert text_of_element(doc, @growth_price_tag_amount) == "€40"
      assert text_of_element(doc, @business_price_tag_amount) == "€120"

      doc = set_slider(lv, "1M")
      assert text_of_element(doc, @slider_value) == "1M"
      assert text_of_element(doc, @growth_price_tag_amount) == "€50"
      assert text_of_element(doc, @business_price_tag_amount) == "€130"

      doc = set_slider(lv, "2M")
      assert text_of_element(doc, @slider_value) == "2M"
      assert text_of_element(doc, @growth_price_tag_amount) == "€60"
      assert text_of_element(doc, @business_price_tag_amount) == "€140"

      doc = set_slider(lv, "5M")
      assert text_of_element(doc, @slider_value) == "5M"
      assert text_of_element(doc, @growth_price_tag_amount) == "€70"
      assert text_of_element(doc, @business_price_tag_amount) == "€150"

      doc = set_slider(lv, "10M")
      assert text_of_element(doc, @slider_value) == "10M"
      assert text_of_element(doc, @growth_price_tag_amount) == "€80"
      assert text_of_element(doc, @business_price_tag_amount) == "€160"
    end

    test "renders contact links for business and growth tiers when enterprise-level volume selected",
         %{
           conn: conn
         } do
      {:ok, lv, _doc} = get_liveview(conn)

      doc = set_slider(lv, "10M+")

      assert text_of_element(doc, "#growth-custom-price") =~ "Custom"
      assert text_of_element(doc, @growth_plan_box) =~ "Contact us"
      assert text_of_element(doc, "#business-custom-price") =~ "Custom"
      assert text_of_element(doc, @business_plan_box) =~ "Contact us"

      doc = set_slider(lv, "10M")

      refute text_of_element(doc, "#growth-custom-price") =~ "Custom"
      refute text_of_element(doc, @growth_plan_box) =~ "Contact us"
      refute text_of_element(doc, "#business-custom-price") =~ "Custom"
      refute text_of_element(doc, @business_plan_box) =~ "Contact us"
    end

    test "switching billing interval changes business and growth prices", %{conn: conn} do
      {:ok, lv, doc} = get_liveview(conn)

      assert text_of_element(doc, @growth_price_tag_amount) == "€10"
      assert text_of_element(doc, @growth_price_tag_interval) == "/month"

      assert text_of_element(doc, @business_price_tag_amount) == "€90"
      assert text_of_element(doc, @business_price_tag_interval) == "/month"

      doc = element(lv, @yearly_interval_button) |> render_click()

      assert text_of_element(doc, @growth_price_tag_amount) == "€100"
      assert text_of_element(doc, @growth_price_tag_interval) == "/year"

      assert text_of_element(doc, @business_price_tag_amount) == "€900"
      assert text_of_element(doc, @business_price_tag_interval) == "/year"
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
               "passthrough" => "user:#{user.id};team:#{team.id}",
               "product" => @v4_growth_200k_yearly_plan_id,
               "success" => Routes.billing_path(PlausibleWeb.Endpoint, :upgrade_success),
               "theme" => "none"
             } == get_paddle_checkout_params(find(doc, @growth_checkout_button))

      set_slider(lv, "5M")
      doc = element(lv, @monthly_interval_button) |> render_click()

      assert get_paddle_checkout_params(find(doc, @business_checkout_button))["product"] ==
               @v4_business_5m_monthly_plan_id
    end

    test "warns about losing access to a feature", %{conn: conn, site: site} do
      Plausible.Props.allow(site, ["author"])

      {:ok, _lv, doc} = get_liveview(conn)

      assert text_of_attr(find(doc, @growth_checkout_button), "onclick") =~
               "if (confirm(\"This plan does not support Custom Properties, which you have been using. By subscribing to this plan, you will not have access to this feature.\")) {Paddle.Checkout.open"
    end

    test "recommends Growth tier when no premium features were used", %{conn: conn} do
      {:ok, _lv, doc} = get_liveview(conn)

      assert text_of_element(doc, @growth_highlight_pill) == "Recommended"
      refute element_exists?(doc, @business_highlight_pill)
    end

    test "recommends Business when Revenue Goals used during trial", %{conn: conn, site: site} do
      insert(:goal, site: site, currency: :USD, event_name: "Purchase")

      {:ok, _lv, doc} = get_liveview(conn)

      assert text_of_element(doc, @business_highlight_pill) == "Recommended"
      refute element_exists?(doc, @growth_highlight_pill)
    end

    test "recommends Business when pending ownership site used a premium feature", %{
      conn: conn,
      user: user
    } do
      previous_owner = insert(:user)
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
      for _ <- 1..9, do: new_site(owner: user)
      assert 10 = Plausible.Teams.Adapter.Read.Billing.site_usage(user)

      another_user = new_user()
      pending_ownership_site = new_site(owner: another_user)

      invite_transfer(pending_ownership_site, user, inviter: another_user)

      {:ok, _lv, doc} = get_liveview(conn)

      assert text_of_element(doc, @business_highlight_pill) == "Recommended"
      refute element_exists?(doc, @growth_highlight_pill)
    end

    @tag :slow
    test "allows upgrade to a 100k plan with a pageview allowance margin of 0.15 when trial is active",
         %{conn: conn, site: site} do
      generate_usage_for(site, 115_000)

      {:ok, lv, _doc} = get_liveview(conn)
      doc = set_slider(lv, "100k")

      refute class_of_element(doc, @growth_checkout_button) =~ "pointer-events-none"
      refute class_of_element(doc, @business_checkout_button) =~ "pointer-events-none"
      refute element_exists?(doc, @growth_plan_tooltip)

      generate_usage_for(site, 1)

      {:ok, lv, _doc} = get_liveview(conn)
      doc = set_slider(lv, "100k")

      assert class_of_element(doc, @growth_checkout_button) =~ "pointer-events-none"
      assert class_of_element(doc, @business_checkout_button) =~ "pointer-events-none"

      assert text_of_element(doc, @growth_plan_tooltip) ==
               "Your usage exceeds the following limit(s): Monthly pageview limit"
    end

    test "allows upgrade to a 10k plan with a pageview allowance margin of 0.3 when trial ended 10 days ago",
         %{conn: conn, site: site, user: user} do
      user
      |> Plausible.Auth.User.changeset(%{trial_expiry_date: Timex.shift(Timex.today(), days: -10)})
      |> Repo.update!()
      |> Plausible.Teams.sync_team()

      generate_usage_for(site, 13_000)

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

    test "pageview allowance margin on upgrade is 0.1 when trial ended more than 10 days ago", %{
      conn: conn,
      site: site,
      user: user
    } do
      user
      |> Plausible.Auth.User.changeset(%{trial_expiry_date: Timex.shift(Timex.today(), days: -11)})
      |> Repo.update!()
      |> Plausible.Teams.sync_team()

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

  describe "for a user with a v4 growth subscription plan" do
    setup [:create_user, :create_site, :log_in, :subscribe_v4_growth]

    test "displays basic page content", %{conn: conn} do
      {:ok, _lv, doc} = get_liveview(conn)

      assert doc =~ "Change subscription plan"
      assert doc =~ "Questions?"
      refute doc =~ "What happens if I go over my page views limit?"
    end

    test "displays plan benefits", %{conn: conn} do
      {:ok, _lv, doc} = get_liveview(conn)

      growth_box = text_of_element(doc, @growth_plan_box)
      business_box = text_of_element(doc, @business_plan_box)
      enterprise_box = text_of_element(doc, @enterprise_plan_box)

      assert growth_box =~ "Up to 3 team members"
      assert growth_box =~ "Up to 10 sites"
      assert growth_box =~ "Intuitive, fast and privacy-friendly dashboard"
      assert growth_box =~ "Email/Slack reports"
      assert growth_box =~ "Google Analytics import"
      assert growth_box =~ "Goals and custom events"
      assert growth_box =~ "3 years of data retention"

      assert business_box =~ "Everything in Growth"
      assert business_box =~ "Up to 10 team members"
      assert business_box =~ "Up to 50 sites"
      assert business_box =~ "Stats API (600 requests per hour)"
      assert business_box =~ "Custom Properties"
      assert business_box =~ "Funnels"
      assert business_box =~ "Ecommerce revenue attribution"
      assert business_box =~ "Priority support"
      assert business_box =~ "5 years of data retention"

      refute business_box =~ "Goals and custom events"

      assert enterprise_box =~ "Everything in Business"
      assert enterprise_box =~ "10+ team members"
      assert enterprise_box =~ "50+ sites"
      assert enterprise_box =~ "600+ Stats API requests per hour"
      assert enterprise_box =~ "Sites API access for"
      assert enterprise_box =~ "Technical onboarding"
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

      assert doc =~ "Your account has been invited to become the owner of a site"

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

    test "gets default selected interval from current subscription plan", %{conn: conn} do
      {:ok, _lv, doc} = get_liveview(conn)
      assert class_of_element(doc, @yearly_interval_button) =~ @interval_button_active_class
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

      assert text_of_element(doc, @growth_checkout_button) == "Currently on this plan"
      assert class_of_element(doc, @growth_checkout_button) =~ "pointer-events-none bg-gray-400"
      assert text_of_element(doc, @business_checkout_button) == "Upgrade to Business"

      doc = element(lv, @monthly_interval_button) |> render_click()

      assert text_of_element(doc, @growth_checkout_button) == "Change billing interval"
      assert text_of_element(doc, @business_checkout_button) == "Upgrade to Business"

      doc = set_slider(lv, "1M")

      assert text_of_element(doc, @growth_checkout_button) == "Upgrade"
      assert text_of_element(doc, @business_checkout_button) == "Upgrade to Business"

      doc = set_slider(lv, "100k")

      assert text_of_element(doc, @growth_checkout_button) == "Downgrade"
      assert text_of_element(doc, @business_checkout_button) == "Upgrade to Business"
    end

    test "checkout buttons are dynamic links to /billing/change-plan/preview/<plan_id>", %{
      conn: conn
    } do
      {:ok, lv, doc} = get_liveview(conn)

      growth_checkout_button = find(doc, @growth_checkout_button)

      assert text_of_attr(growth_checkout_button, "onclick") =~
               "if (true) {window.location = '#{Routes.billing_path(conn, :change_plan_preview, @v4_growth_10k_yearly_plan_id)}'}"

      set_slider(lv, "5M")
      doc = element(lv, @monthly_interval_button) |> render_click()

      business_checkout_button = find(doc, @business_checkout_button)

      assert text_of_attr(business_checkout_button, "onclick") =~
               "if (true) {window.location = '#{Routes.billing_path(conn, :change_plan_preview, @v4_business_5m_monthly_plan_id)}'}"
    end
  end

  describe "for a user with a v4 business subscription plan" do
    setup [:create_user, :create_site, :log_in, :subscribe_v4_business]

    test "sets pageview slider according to last cycle usage", %{conn: conn} do
      {:ok, _lv, doc} = get_liveview(conn)
      assert text_of_element(doc, @slider_value) == "10k"
    end

    test "highlights Business box as the 'Current' tier if it's suitable for their usage", %{
      conn: conn,
      site: site
    } do
      insert(:goal, site: site, currency: :USD, event_name: "Purchase")

      {:ok, _lv, doc} = get_liveview(conn)

      class = class_of_element(doc, @business_plan_box)

      assert class =~ "ring-2"
      assert class =~ "ring-indigo-600"
      assert text_of_element(doc, @business_highlight_pill) == "Current"

      refute element_exists?(doc, @growth_highlight_pill)
    end

    test "highlights Growth box as the 'Recommended' tier if it would accommodate their usage", %{
      conn: conn
    } do
      {:ok, _lv, doc} = get_liveview(conn)

      class = class_of_element(doc, @growth_plan_box)

      assert class =~ "ring-2"
      assert class =~ "ring-indigo-600"
      assert text_of_element(doc, @growth_highlight_pill) == "Recommended"

      refute element_exists?(doc, @business_highlight_pill)
    end

    test "recommends Enterprise when site limit exceeds Business tier due to pending ownerships",
         %{
           conn: conn,
           user: user
         } do
      for _ <- 1..49 do
        new_site(owner: user)
      end

      assert 50 = Plausible.Teams.Adapter.Read.Billing.quota_usage(user).sites

      another_user = new_user()
      pending_ownership_site = new_site(owner: another_user)

      invite_transfer(pending_ownership_site, user, inviter: another_user)

      {:ok, _lv, doc} = get_liveview(conn)

      assert text_of_element(doc, @enterprise_highlight_pill) == "Recommended"
      refute element_exists?(doc, @business_highlight_pill)
      refute element_exists?(doc, @growth_highlight_pill)
    end

    test "checkout button text and click-disabling CSS classes are dynamic", %{conn: conn} do
      {:ok, lv, _doc} = get_liveview(conn)

      doc = set_slider(lv, "5M")

      assert text_of_element(doc, @business_checkout_button) == "Currently on this plan"
      assert class_of_element(doc, @business_checkout_button) =~ "pointer-events-none bg-gray-400"

      doc = element(lv, @yearly_interval_button) |> render_click()

      assert text_of_element(doc, @business_checkout_button) == "Change billing interval"
      assert text_of_element(doc, @growth_checkout_button) == "Downgrade to Growth"

      doc = set_slider(lv, "10M")

      assert text_of_element(doc, @business_checkout_button) == "Upgrade"
      assert text_of_element(doc, @growth_checkout_button) == "Downgrade to Growth"

      doc = set_slider(lv, "100k")

      assert text_of_element(doc, @business_checkout_button) == "Downgrade"
      assert text_of_element(doc, @growth_checkout_button) == "Downgrade to Growth"
    end

    test "checkout is disabled when team member usage exceeds rendered plan limit", %{
      conn: conn,
      user: user
    } do
      site = new_site(owner: user)
      for _ <- 1..4, do: add_guest(site, role: :viewer)

      {:ok, _lv, doc} = get_liveview(conn)

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

      Plausible.Users.allow_next_upgrade_override(user)

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

    test "displays plan benefits", %{conn: conn} do
      {:ok, _lv, doc} = get_liveview(conn)

      growth_box = text_of_element(doc, @growth_plan_box)
      business_box = text_of_element(doc, @business_plan_box)
      enterprise_box = text_of_element(doc, @enterprise_plan_box)

      assert growth_box =~ "Up to 3 team members"
      assert growth_box =~ "Up to 10 sites"
      assert growth_box =~ "Intuitive, fast and privacy-friendly dashboard"
      assert growth_box =~ "Email/Slack reports"
      assert growth_box =~ "Google Analytics import"
      assert growth_box =~ "Goals and custom events"

      assert business_box =~ "Everything in Growth"
      assert business_box =~ "Unlimited team members"
      assert business_box =~ "Up to 50 sites"
      assert business_box =~ "Stats API (600 requests per hour)"
      assert business_box =~ "Custom Properties"
      assert business_box =~ "Funnels"
      assert business_box =~ "Ecommerce revenue attribution"
      assert business_box =~ "Priority support"

      refute business_box =~ "Goals and custom events"

      assert enterprise_box =~ "Everything in Business"
      assert enterprise_box =~ "50+ sites"
      assert enterprise_box =~ "600+ Stats API requests per hour"
      assert enterprise_box =~ "Sites API access for"
      assert enterprise_box =~ "Technical onboarding"

      refute enterprise_box =~ "team members"

      assert text_of_attr(find(doc, "#{@enterprise_plan_box} p a"), "href") =~
               "https://plausible.io/white-label-web-analytics"
    end
  end

  describe "for a user with a past_due subscription" do
    setup [:create_user, :create_site, :log_in, :create_past_due_subscription]

    test "renders failed payment notice and link to update billing details", %{conn: conn} do
      {:ok, _lv, doc} = get_liveview(conn)
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

      assert class_of_element(doc, @business_checkout_button) =~ "pointer-events-none bg-gray-400"

      assert text_of_element(doc, "#{@business_checkout_button} + div") =~
               "Please update your billing details first"

      doc = set_slider(lv, "1M")

      assert class_of_element(doc, @growth_checkout_button) =~ "pointer-events-none bg-gray-400"

      assert text_of_element(doc, "#{@growth_checkout_button} + div") =~
               "Please update your billing details first"
    end
  end

  describe "for a user with a paused subscription" do
    setup [:create_user, :create_site, :log_in, :create_paused_subscription]

    test "renders subscription paused notice and link to update billing details", %{conn: conn} do
      {:ok, _lv, doc} = get_liveview(conn)
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

      assert class_of_element(doc, @business_checkout_button) =~ "pointer-events-none bg-gray-400"

      assert text_of_element(doc, "#{@business_checkout_button} + div") =~
               "Please update your billing details first"

      doc = set_slider(lv, "1M")

      assert class_of_element(doc, @growth_checkout_button) =~ "pointer-events-none bg-gray-400"

      assert text_of_element(doc, "#{@growth_checkout_button} + div") =~
               "Please update your billing details first"
    end
  end

  describe "for a user with a cancelled subscription" do
    setup [:create_user, :create_site, :log_in, :create_cancelled_subscription]

    test "checkout buttons are paddle buttons", %{conn: conn} do
      {:ok, _lv, doc} = get_liveview(conn)
      assert text_of_attr(find(doc, @growth_checkout_button), "onclick") =~ "Paddle.Checkout.open"

      assert text_of_attr(find(doc, @business_checkout_button), "onclick") =~
               "Paddle.Checkout.open"
    end

    test "currently owned tier is highlighted if stats are still unlocked", %{conn: conn} do
      {:ok, _lv, doc} = get_liveview(conn)
      assert text_of_element(doc, @growth_highlight_pill) == "Current"
    end

    test "can subscribe again to the currently owned (but cancelled) plan", %{conn: conn} do
      {:ok, _lv, doc} = get_liveview(conn)
      refute class_of_element(doc, @growth_checkout_button) =~ "pointer-events-none"
    end

    test "highlights recommended tier if subscription expired and no days are paid for anymore",
         %{conn: conn, user: user} do
      user.subscription
      |> Subscription.changeset(%{next_bill_date: Timex.shift(Timex.now(), months: -2)})
      |> Repo.update()

      {:ok, _lv, doc} = get_liveview(conn)
      assert text_of_element(doc, @growth_highlight_pill) == "Recommended"
      refute text_of_element(doc, @business_highlight_pill) == "Recommended"
    end
  end

  describe "for a grandfathered user with a high volume plan" do
    setup [:create_user, :create_site, :log_in]

    test "on a 50M v1 plan, Growth tiers are available at 20M, 50M, 50M+, but Business tiers are not",
         %{conn: conn, user: user} do
      create_subscription_for(user, paddle_plan_id: @v1_50m_yearly_plan_id)

      {:ok, lv, _doc} = get_liveview(conn)

      doc = set_slider(lv, 8)
      assert text_of_element(doc, @slider_value) == "20M"
      assert text_of_element(doc, @business_plan_box) =~ "Contact us"
      assert text_of_element(doc, @growth_price_tag_amount) == "€900"
      assert text_of_element(doc, @growth_price_tag_interval) == "/year"

      doc = set_slider(lv, 9)
      assert text_of_element(doc, @slider_value) == "50M"
      assert text_of_element(doc, @business_plan_box) =~ "Contact us"
      assert text_of_element(doc, @growth_price_tag_amount) == "€1,000"
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
      assert text_of_element(doc, @business_plan_box) =~ "Contact us"
      assert text_of_element(doc, @growth_price_tag_amount) == "€900"
      assert text_of_element(doc, @growth_price_tag_interval) == "/year"

      doc = set_slider(lv, 9)
      assert text_of_element(doc, @slider_value) == "20M+"
      assert text_of_element(doc, @business_plan_box) =~ "Contact us"
      assert text_of_element(doc, @growth_plan_box) =~ "Contact us"
    end
  end

  describe "for a grandfathered user on a v1 10k plan" do
    setup [:create_user, :create_site, :log_in]

    setup %{user: user} = context do
      create_subscription_for(user, paddle_plan_id: @v1_10k_yearly_plan_id)
      {:ok, context}
    end

    test "v1 20M and 50M Growth plans are not available",
         %{conn: conn} do
      {:ok, lv, _doc} = get_liveview(conn)

      doc = set_slider(lv, 8)
      assert text_of_element(doc, @slider_value) == "10M+"
      assert text_of_element(doc, @growth_plan_box) =~ "Contact us"
    end

    test "displays grandfathering notice in the Growth box instead of benefits", %{conn: conn} do
      {:ok, _lv, doc} = get_liveview(conn)
      growth_box = text_of_element(doc, @growth_plan_box)
      assert growth_box =~ "Your subscription has been grandfathered"
      refute growth_box =~ "Intuitive, fast and privacy-friendly dashboard"
    end

    test "displays business and enterprise plan benefits", %{conn: conn} do
      {:ok, _lv, doc} = get_liveview(conn)

      business_box = text_of_element(doc, @business_plan_box)
      enterprise_box = text_of_element(doc, @enterprise_plan_box)

      assert business_box =~ "Everything in Growth"
      assert business_box =~ "Funnels"
      assert business_box =~ "Ecommerce revenue attribution"
      assert business_box =~ "Priority support"

      refute business_box =~ "Goals and custom events"
      refute business_box =~ "Unlimited team members"
      refute business_box =~ "Up to 50 sites"
      refute business_box =~ "Stats API (600 requests per hour)"
      refute business_box =~ "Custom Properties"

      assert enterprise_box =~ "Everything in Business"
      assert enterprise_box =~ "50+ sites"
      assert enterprise_box =~ "600+ Stats API requests per hour"
      assert enterprise_box =~ "Sites API access for"
      assert enterprise_box =~ "Technical onboarding"

      assert text_of_attr(find(doc, "#{@enterprise_plan_box} p a"), "href") =~
               "https://plausible.io/white-label-web-analytics"

      refute enterprise_box =~ "10+ team members"
      refute enterprise_box =~ "Unlimited team members"
    end

    test "allows to upgrade without a trial_expiry_date when the user owns a site", %{
      conn: conn,
      user: user
    } do
      user
      |> Plausible.Auth.User.changeset(%{trial_expiry_date: nil})
      |> Repo.update!()

      {:ok, lv, _doc} = get_liveview(conn)
      doc = set_slider(lv, "100k")

      refute class_of_element(doc, @growth_checkout_button) =~ "pointer-events-none"
      refute class_of_element(doc, @business_checkout_button) =~ "pointer-events-none"
    end
  end

  describe "for a free_10k subscription" do
    setup [:create_user, :create_site, :log_in, :subscribe_free_10k]

    test "recommends growth tier when no premium features used", %{conn: conn} do
      {:ok, _lv, doc} = get_liveview(conn)
      assert element_exists?(doc, @growth_highlight_pill)
      refute element_exists?(doc, @business_highlight_pill)
    end

    test "recommends Business tier when premium features used", %{conn: conn, site: site} do
      insert(:goal, currency: :USD, site: site, event_name: "Purchase")

      {:ok, _lv, doc} = get_liveview(conn)

      assert text_of_element(doc, @business_plan_box) =~ "Recommended"
      refute text_of_element(doc, @growth_plan_box) =~ "Recommended"
    end

    test "renders Paddle upgrade buttons", %{conn: conn, user: user} do
      {:ok, lv, _doc} = get_liveview(conn)
      {:ok, team} = Plausible.Teams.get_by_owner(user)

      set_slider(lv, "200k")
      doc = element(lv, @yearly_interval_button) |> render_click()

      assert %{
               "disableLogout" => true,
               "email" => user.email,
               "passthrough" => "user:#{user.id};team:#{team.id}",
               "product" => @v4_growth_200k_yearly_plan_id,
               "success" => Routes.billing_path(PlausibleWeb.Endpoint, :upgrade_success),
               "theme" => "none"
             } == get_paddle_checkout_params(find(doc, @growth_checkout_button))
    end
  end

  describe "for a user with no sites" do
    setup [:create_user, :log_in]

    test "does not allow to subscribe and renders notice", %{conn: conn} do
      {:ok, _lv, doc} = get_liveview(conn)

      assert text_of_element(doc, "#upgrade-eligible-notice") =~ "You cannot start a subscription"
      assert class_of_element(doc, @growth_checkout_button) =~ "pointer-events-none"
      assert class_of_element(doc, @business_checkout_button) =~ "pointer-events-none"
    end
  end

  describe "for a user with no sites but pending ownership transfer" do
    setup [:create_user, :log_in]

    test "allows to subscribe and does not render the 'upgrade ineligible' notice", %{
      conn: conn,
      user: user
    } do
      old_owner = new_user()
      site = new_site(owner: old_owner)
      invite_transfer(site, user, inviter: old_owner)

      {:ok, _lv, doc} = get_liveview(conn)

      refute text_of_element(doc, "#upgrade-eligible-notice") =~ "You cannot start a subscription"
      refute class_of_element(doc, @growth_checkout_button) =~ "pointer-events-none"
      refute class_of_element(doc, @business_checkout_button) =~ "pointer-events-none"
      assert text_of_element(doc, @growth_plan_box) =~ "Recommended"
    end
  end

  defp subscribe_v4_growth(%{user: user}) do
    create_subscription_for(user, paddle_plan_id: @v4_growth_200k_yearly_plan_id)
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
