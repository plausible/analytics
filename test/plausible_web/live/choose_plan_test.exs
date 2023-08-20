defmodule PlausibleWeb.Live.ChoosePlanTest do
  use PlausibleWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

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

      yearly_selector = ~s/label[phx-click="set_interval"][phx-value-interval="yearly"]/
      monthly_selector = ~s/label[phx-click="set_interval"][phx-value-interval="monthly"]/
      active_class = "bg-indigo-600 text-white"

      doc
      |> find(monthly_selector)
      |> text_of_attr("class")
      |> then(fn class -> assert class =~ active_class end)

      doc
      |> find(yearly_selector)
      |> text_of_attr("class")
      |> then(fn class -> refute class =~ active_class end)

      doc =
        lv
        |> element(yearly_selector)
        |> render_click()

      doc
      |> find(monthly_selector)
      |> text_of_attr("class")
      |> then(fn class -> refute class =~ active_class end)

      doc
      |> find(yearly_selector)
      |> text_of_attr("class")
      |> then(fn class -> assert class =~ active_class end)
    end
  end

  describe "for a user with a v4 growth subscription plan" do
    setup [:create_user, :log_in, :subscribe]

    test "displays basic page content", %{conn: conn, user: user} do
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

    test "gets default active interval from current subscription plan"
  end

  @v4_growth_200k_yearly_plan_id "change-me-749347"

  defp subscribe(%{user: user}) do
    insert(:subscription, user: user, paddle_plan_id: @v4_growth_200k_yearly_plan_id)
    {:ok, user: Plausible.Users.with_subscription(user)}
  end

  defp get_liveview(conn) do
    conn = assign(conn, :live_module, PlausibleWeb.Live.ChoosePlan)
    {:ok, _lv, _doc} = live(conn, "/billing/choose-plan")
  end
end
