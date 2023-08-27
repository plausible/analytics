defmodule PlausibleWeb.Live.ChoosePlanTest do
  use PlausibleWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  @monthly_interval_button ~s/label[phx-click="set_interval"][phx-value-interval="monthly"]/
  @yearly_interval_button ~s/label[phx-click="set_interval"][phx-value-interval="yearly"]/
  @interval_button_active_class "bg-indigo-600 text-white"
  @slider_input ~s/input[name="slider"]/
  @plan_box_growth "#plan-box-growth"
  @plan_box_business "#plan-box-business"
  @growth_price_tag_amount "#{@plan_box_growth} > p > span:first-child"
  @growth_price_tag_interval "#{@plan_box_growth} > p > span:nth-child(2)"
  @growth_current_label "#{@plan_box_growth} > div.absolute"
  @business_price_tag_amount "#{@plan_box_business} > p > span:first-child"
  @business_price_tag_interval "#{@plan_box_business} > p > span:nth-child(2)"
  @business_current_label "#{@plan_box_business} > div.absolute"

  describe "for a user with no subscription" do
    setup [:create_user, :log_in]

    test "displays basic page content", %{conn: conn} do
      {:ok, _lv, doc} = get_liveview(conn)

      assert doc =~ "Upgrade your free trial"
      assert doc =~ "You have used <b>0</b>\nbillable pageviews in the last 30 days"
      assert doc =~ "Questions?"
      assert doc =~ "What happens if I go over my page views limit?"
    end

    test "default billing interval is monthly, and can switch to yearly", %{conn: conn} do
      {:ok, lv, doc} = get_liveview(conn)

      doc
      |> find(@monthly_interval_button)
      |> text_of_attr("class")
      |> then(fn class -> assert class =~ @interval_button_active_class end)

      doc
      |> find(@yearly_interval_button)
      |> text_of_attr("class")
      |> then(fn class -> refute class =~ @interval_button_active_class end)

      doc =
        lv
        |> element(@yearly_interval_button)
        |> render_click()

      doc
      |> find(@monthly_interval_button)
      |> text_of_attr("class")
      |> then(fn class -> refute class =~ @interval_button_active_class end)

      doc
      |> find(@yearly_interval_button)
      |> text_of_attr("class")
      |> then(fn class -> assert class =~ @interval_button_active_class end)
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
  end

  describe "for a user with a v4 growth subscription plan" do
    setup [:create_user, :log_in, :subscribe_growth]

    test "displays basic page content", %{conn: conn} do
      {:ok, _lv, doc} = get_liveview(conn)

      assert doc =~ "Upgrade subscription plan"
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

      doc
      |> find(@yearly_interval_button)
      |> text_of_attr("class")
      |> then(fn class -> assert class =~ @interval_button_active_class end)
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

      class =
        doc
        |> find(@plan_box_growth)
        |> text_of_attr("class")

      assert class =~ "ring-2"
      assert class =~ "ring-indigo-600"
      assert text_of_element(doc, @growth_current_label) == "CURRENT"
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

      class =
        doc
        |> find(@plan_box_business)
        |> text_of_attr("class")

      assert class =~ "ring-2"
      assert class =~ "ring-indigo-600"
      assert text_of_element(doc, @business_current_label) == "CURRENT"
    end
  end

  @v4_growth_200k_yearly_plan_id "change-me-749347"

  defp subscribe_growth(%{user: user}) do
    insert(:subscription, user: user, paddle_plan_id: @v4_growth_200k_yearly_plan_id)
    {:ok, user: Plausible.Users.with_subscription(user)}
  end

  @v4_business_5m_monthly_plan_id "change-me-b749356"

  defp subscribe_business(%{user: user}) do
    insert(:subscription, user: user, paddle_plan_id: @v4_business_5m_monthly_plan_id)
    {:ok, user: Plausible.Users.with_subscription(user)}
  end

  defp get_liveview(conn) do
    conn = assign(conn, :live_module, PlausibleWeb.Live.ChoosePlan)
    {:ok, _lv, _doc} = live(conn, "/billing/choose-plan")
  end
end
