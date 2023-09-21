defmodule PlausibleWeb.Live.ChoosePlanTest do
  alias Plausible.{Repo, Billing.Subscription}
  use PlausibleWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  @v4_growth_200k_yearly_plan_id "change-me-749347"
  @v4_business_5m_monthly_plan_id "change-me-b749356"

  @monthly_interval_button ~s/label[phx-click="set_interval"][phx-value-interval="monthly"]/
  @yearly_interval_button ~s/label[phx-click="set_interval"][phx-value-interval="yearly"]/
  @interval_button_active_class "bg-indigo-600 text-white"
  @slider_input ~s/input[name="slider"]/

  @plan_box_growth "#plan-box-growth"
  @growth_price_tag "#growth-price-tag"
  @growth_price_tag_amount "#{@growth_price_tag} > span:first-child"
  @growth_price_tag_interval "#{@growth_price_tag} > span:nth-child(2)"
  @growth_current_label "#{@plan_box_growth} > div.absolute"
  @growth_checkout_button "#growth-checkout"

  @plan_box_business "#plan-box-business"
  @business_price_tag "#business-price-tag"
  @business_price_tag_amount "#{@business_price_tag} > span:first-child"
  @business_price_tag_interval "#{@business_price_tag} > span:nth-child(2)"
  @business_current_label "#{@plan_box_business} > div.absolute"
  @business_checkout_button "#business-checkout"

  describe "for a user with no subscription" do
    setup [:create_user, :log_in]

    test "displays basic page content", %{conn: conn} do
      {:ok, _lv, doc} = get_liveview(conn)

      assert doc =~ "Upgrade your account"
      assert doc =~ "You have used <b>0</b>\nbillable pageviews in the last 30 days"
      assert doc =~ "Questions?"
      assert doc =~ "What happens if I go over my page views limit?"
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
      assert doc =~ "Monthly pageviews: <b>10k</b"
      assert text_of_element(doc, @growth_price_tag_amount) == "€10"
      assert text_of_element(doc, @business_price_tag_amount) == "€90"
    end

    test "pageview slider changes selected volume and prices shown", %{conn: conn} do
      {:ok, lv, _doc} = get_liveview(conn)

      doc = lv |> element(@slider_input) |> render_change(%{slider: 1})
      assert doc =~ "Monthly pageviews: <b>100k</b"
      assert text_of_element(doc, @growth_price_tag_amount) == "€20"
      assert text_of_element(doc, @business_price_tag_amount) == "€100"

      doc = lv |> element(@slider_input) |> render_change(%{slider: 2})
      assert doc =~ "Monthly pageviews: <b>200k</b"
      assert text_of_element(doc, @growth_price_tag_amount) == "€30"
      assert text_of_element(doc, @business_price_tag_amount) == "€110"

      doc = lv |> element(@slider_input) |> render_change(%{slider: 3})
      assert doc =~ "Monthly pageviews: <b>500k</b"
      assert text_of_element(doc, @growth_price_tag_amount) == "€40"
      assert text_of_element(doc, @business_price_tag_amount) == "€120"

      doc = lv |> element(@slider_input) |> render_change(%{slider: 4})
      assert doc =~ "Monthly pageviews: <b>1M</b"
      assert text_of_element(doc, @growth_price_tag_amount) == "€50"
      assert text_of_element(doc, @business_price_tag_amount) == "€130"

      doc = lv |> element(@slider_input) |> render_change(%{slider: 5})
      assert doc =~ "Monthly pageviews: <b>2M</b"
      assert text_of_element(doc, @growth_price_tag_amount) == "€60"
      assert text_of_element(doc, @business_price_tag_amount) == "€140"

      doc = lv |> element(@slider_input) |> render_change(%{slider: 6})
      assert doc =~ "Monthly pageviews: <b>5M</b"
      assert text_of_element(doc, @growth_price_tag_amount) == "€70"
      assert text_of_element(doc, @business_price_tag_amount) == "€150"

      doc = lv |> element(@slider_input) |> render_change(%{slider: 7})
      assert doc =~ "Monthly pageviews: <b>10M</b"
      assert text_of_element(doc, @growth_price_tag_amount) == "€80"
      assert text_of_element(doc, @business_price_tag_amount) == "€160"
    end

    test "renders business and growth tiers unavailable when enterprise-level volume selected", %{
      conn: conn
    } do
      {:ok, lv, _doc} = get_liveview(conn)

      doc = lv |> element(@slider_input) |> render_change(%{slider: 8})

      assert class_of_element(doc, "#growth-body") =~ "hidden"
      assert class_of_element(doc, "#business-body") =~ "hidden"

      assert text_of_element(doc, "#{@plan_box_growth} > p") == "Unavailable at this volume"
      assert text_of_element(doc, "#{@plan_box_business} > p") == "Unavailable at this volume"

      doc = lv |> element(@slider_input) |> render_change(%{slider: 7})

      refute class_of_element(doc, "#growth-body") =~ "hidden"
      refute class_of_element(doc, "#business-body") =~ "hidden"

      refute element_exists?(doc, "#{@plan_box_growth} > p")
      refute element_exists?(doc, "#{@plan_box_business} > p")
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

    test "checkout buttons are 'paddle buttons' with dynamic attributes", %{
      conn: conn,
      user: user
    } do
      {:ok, lv, _doc} = get_liveview(conn)

      element(lv, @slider_input) |> render_change(%{slider: 2})
      doc = element(lv, @yearly_interval_button) |> render_click()

      growth_checkout_button = find(doc, @growth_checkout_button)

      assert text_of_attr(growth_checkout_button, "class") =~ "paddle_button"

      assert text_of_attr(growth_checkout_button, "data-product") ==
               @v4_growth_200k_yearly_plan_id

      assert text_of_attr(growth_checkout_button, "data-email") == user.email
      assert text_of_attr(growth_checkout_button, "data-passthrough") == to_string(user.id)

      element(lv, @slider_input) |> render_change(%{slider: 6})
      doc = element(lv, @monthly_interval_button) |> render_click()

      business_checkout_button = find(doc, @business_checkout_button)

      assert text_of_attr(business_checkout_button, "class") =~ "paddle_button"

      assert text_of_attr(business_checkout_button, "data-product") ==
               @v4_business_5m_monthly_plan_id

      assert text_of_attr(business_checkout_button, "data-email") == user.email
      assert text_of_attr(business_checkout_button, "data-passthrough") == to_string(user.id)
    end
  end

  describe "for a user with a v4 growth subscription plan" do
    setup [:create_user, :log_in, :subscribe_growth]

    test "displays basic page content", %{conn: conn} do
      {:ok, _lv, doc} = get_liveview(conn)

      assert doc =~ "Change subscription plan"
      assert doc =~ "Questions?"
      refute doc =~ "What happens if I go over my page views limit?"
    end

    test "displays usage", %{conn: conn, user: user} do
      site = insert(:site, members: [user])

      populate_stats(site, [
        build(:pageview),
        build(:pageview)
      ])

      {:ok, _lv, doc} = get_liveview(conn)
      assert doc =~ "You have used <b>2</b>\nbillable pageviews in the last 30 days"
    end

    test "gets default selected interval from current subscription plan", %{conn: conn} do
      {:ok, _lv, doc} = get_liveview(conn)
      assert class_of_element(doc, @yearly_interval_button) =~ @interval_button_active_class
    end

    test "gets default pageview limit from current subscription plan", %{conn: conn} do
      {:ok, _lv, doc} = get_liveview(conn)
      assert doc =~ "Monthly pageviews: <b>200k</b"
    end

    test "pageview slider changes selected volume", %{conn: conn} do
      {:ok, lv, _doc} = get_liveview(conn)

      doc = lv |> element(@slider_input) |> render_change(%{slider: 1})
      assert doc =~ "Monthly pageviews: <b>100k</b"

      doc = lv |> element(@slider_input) |> render_change(%{slider: 0})
      assert doc =~ "Monthly pageviews: <b>10k</b"
    end

    test "makes it clear that the user is currently on a growth tier", %{conn: conn} do
      {:ok, _lv, doc} = get_liveview(conn)

      class = class_of_element(doc, @plan_box_growth)

      assert class =~ "ring-2"
      assert class =~ "ring-indigo-600"
      assert text_of_element(doc, @growth_current_label) == "CURRENT"
    end

    test "checkout button text and click-disabling CSS classes are dynamic", %{conn: conn} do
      {:ok, lv, doc} = get_liveview(conn)

      assert text_of_element(doc, @growth_checkout_button) == "Currently on this plan"
      assert class_of_element(doc, @growth_checkout_button) =~ "pointer-events-none bg-gray-400"
      assert text_of_element(doc, @business_checkout_button) == "Upgrade to Business"

      doc = element(lv, @monthly_interval_button) |> render_click()

      assert text_of_element(doc, @growth_checkout_button) == "Change billing interval"
      assert text_of_element(doc, @business_checkout_button) == "Upgrade to Business"

      doc = lv |> element(@slider_input) |> render_change(%{slider: 4})

      assert text_of_element(doc, @growth_checkout_button) == "Upgrade"
      assert text_of_element(doc, @business_checkout_button) == "Upgrade to Business"

      doc = lv |> element(@slider_input) |> render_change(%{slider: 1})

      assert text_of_element(doc, @growth_checkout_button) == "Downgrade"
      assert text_of_element(doc, @business_checkout_button) == "Upgrade to Business"
    end

    test "checkout buttons are dynamic links to /billing/change-plan/preview/<plan_id>", %{
      conn: conn
    } do
      {:ok, lv, doc} = get_liveview(conn)

      growth_checkout_button = find(doc, @growth_checkout_button)

      assert text_of_attr(growth_checkout_button, "href") =~
               "/billing/change-plan/preview/#{@v4_growth_200k_yearly_plan_id}"

      element(lv, @slider_input) |> render_change(%{slider: 6})
      doc = element(lv, @monthly_interval_button) |> render_click()

      business_checkout_button = find(doc, @business_checkout_button)

      assert text_of_attr(business_checkout_button, "href") =~
               "/billing/change-plan/preview/#{@v4_business_5m_monthly_plan_id}"
    end
  end

  describe "for a user with a v4 business subscription plan" do
    setup [:create_user, :log_in, :subscribe_business]

    test "gets default pageview limit from current subscription plan", %{conn: conn} do
      {:ok, _lv, doc} = get_liveview(conn)
      assert doc =~ "Monthly pageviews: <b>5M</b"
    end

    test "makes it clear that the user is currently on a business tier", %{conn: conn} do
      {:ok, _lv, doc} = get_liveview(conn)

      class = class_of_element(doc, @plan_box_business)

      assert class =~ "ring-2"
      assert class =~ "ring-indigo-600"
      assert text_of_element(doc, @business_current_label) == "CURRENT"
    end

    test "checkout button text and click-disabling CSS classes are dynamic", %{conn: conn} do
      {:ok, lv, doc} = get_liveview(conn)

      assert text_of_element(doc, @business_checkout_button) == "Currently on this plan"
      assert class_of_element(doc, @business_checkout_button) =~ "pointer-events-none bg-gray-400"
      assert text_of_element(doc, @growth_checkout_button) == "Downgrade to Growth"

      doc = element(lv, @yearly_interval_button) |> render_click()

      assert text_of_element(doc, @business_checkout_button) == "Change billing interval"
      assert text_of_element(doc, @growth_checkout_button) == "Downgrade to Growth"

      doc = lv |> element(@slider_input) |> render_change(%{slider: 7})

      assert text_of_element(doc, @business_checkout_button) == "Upgrade"
      assert text_of_element(doc, @growth_checkout_button) == "Downgrade to Growth"

      doc = lv |> element(@slider_input) |> render_change(%{slider: 1})

      assert text_of_element(doc, @business_checkout_button) == "Downgrade"
      assert text_of_element(doc, @growth_checkout_button) == "Downgrade to Growth"
    end
  end

  describe "for a user with a past_due subscription" do
    setup [:create_user, :log_in, :create_past_due_subscription]

    test "renders failed payment notice and link to update billing details", %{conn: conn} do
      {:ok, _lv, doc} = get_liveview(conn)
      assert doc =~ "There was a problem with your latest payment"
      assert doc =~ "https://update.billing.details"
    end

    test "checkout buttons are disabled + notice about billing details (unless plan owned already)",
         %{conn: conn} do
      {:ok, lv, doc} = get_liveview(conn)
      assert class_of_element(doc, @growth_checkout_button) =~ "pointer-events-none bg-gray-400"
      assert text_of_element(doc, @growth_checkout_button) =~ "Currently on this plan"
      refute element_exists?(doc, "#{@growth_checkout_button} + p")

      assert class_of_element(doc, @business_checkout_button) =~ "pointer-events-none bg-gray-400"

      assert text_of_element(doc, "#{@business_checkout_button} + p") =~
               "Please update your billing details first"

      doc = lv |> element(@slider_input) |> render_change(%{slider: 4})

      assert class_of_element(doc, @growth_checkout_button) =~ "pointer-events-none bg-gray-400"

      assert text_of_element(doc, "#{@growth_checkout_button} + p") =~
               "Please update your billing details first"
    end
  end

  describe "for a user with a paused subscription" do
    setup [:create_user, :log_in, :create_paused_subscription]

    test "renders subscription paused notice and link to update billing details", %{conn: conn} do
      {:ok, _lv, doc} = get_liveview(conn)
      assert doc =~ "Your subscription is paused due to failed payments"
      assert doc =~ "https://update.billing.details"
    end

    test "checkout buttons are disabled + notice about billing details when plan not owned already",
         %{conn: conn} do
      {:ok, lv, doc} = get_liveview(conn)
      assert class_of_element(doc, @growth_checkout_button) =~ "pointer-events-none bg-gray-400"
      assert text_of_element(doc, @growth_checkout_button) =~ "Currently on this plan"
      refute element_exists?(doc, "#{@growth_checkout_button} + p")

      assert class_of_element(doc, @business_checkout_button) =~ "pointer-events-none bg-gray-400"

      assert text_of_element(doc, "#{@business_checkout_button} + p") =~
               "Please update your billing details first"

      doc = lv |> element(@slider_input) |> render_change(%{slider: 4})

      assert class_of_element(doc, @growth_checkout_button) =~ "pointer-events-none bg-gray-400"

      assert text_of_element(doc, "#{@growth_checkout_button} + p") =~
               "Please update your billing details first"
    end
  end

  describe "for a user with a cancelled subscription" do
    setup [:create_user, :log_in, :create_cancelled_subscription]

    test "checkout buttons are paddle buttons", %{conn: conn} do
      {:ok, _lv, doc} = get_liveview(conn)
      assert class_of_element(doc, @growth_checkout_button) =~ "paddle_button"
      assert class_of_element(doc, @business_checkout_button) =~ "paddle_button"
    end

    test "currently owned tier is highlighted if stats are still unlocked", %{conn: conn} do
      {:ok, _lv, doc} = get_liveview(conn)
      assert text_of_element(doc, @growth_current_label) == "CURRENT"
    end

    test "currently owned tier is not highlighted if stats are locked", %{conn: conn, user: user} do
      user.subscription
      |> Subscription.changeset(%{next_bill_date: Timex.shift(Timex.now(), months: -2)})
      |> Repo.update()

      {:ok, _lv, doc} = get_liveview(conn)
      refute element_exists?(doc, @growth_current_label)
    end
  end

  defp subscribe_growth(%{user: user}) do
    insert(:subscription, user: user, paddle_plan_id: @v4_growth_200k_yearly_plan_id)
    {:ok, user: Plausible.Users.with_subscription(user)}
  end

  defp subscribe_business(%{user: user}) do
    insert(:subscription, user: user, paddle_plan_id: @v4_business_5m_monthly_plan_id)
    {:ok, user: Plausible.Users.with_subscription(user)}
  end

  defp create_past_due_subscription(%{user: user}) do
    insert(:subscription,
      user: user,
      paddle_plan_id: @v4_growth_200k_yearly_plan_id,
      status: "past_due",
      update_url: "https://update.billing.details"
    )

    {:ok, user: Plausible.Users.with_subscription(user)}
  end

  defp create_paused_subscription(%{user: user}) do
    insert(:subscription,
      user: user,
      paddle_plan_id: @v4_growth_200k_yearly_plan_id,
      status: "paused",
      update_url: "https://update.billing.details"
    )

    {:ok, user: Plausible.Users.with_subscription(user)}
  end

  defp create_cancelled_subscription(%{user: user}) do
    insert(:subscription,
      user: user,
      paddle_plan_id: @v4_growth_200k_yearly_plan_id,
      status: "deleted"
    )

    {:ok, user: Plausible.Users.with_subscription(user)}
  end

  defp get_liveview(conn) do
    conn = assign(conn, :live_module, PlausibleWeb.Live.ChoosePlan)
    {:ok, _lv, _doc} = live(conn, "/billing/choose-plan")
  end
end
