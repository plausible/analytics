defmodule PlausibleWeb.BillingControllerTest do
  use PlausibleWeb.ConnCase, async: true
  use Plausible.Teams.Test
  import Plausible.Test.Support.HTML
  require Plausible.Billing.Subscription.Status
  alias Plausible.Billing.Subscription

  @v4_growth_plan "857097"
  @v4_business_plan "857105"

  describe "GET /choose-plan" do
    setup [:create_user, :log_in]

    test "redirects to enterprise upgrade page if user has an enterprise plan configured",
         %{conn: conn, user: user} do
      subscribe_to_enterprise_plan(user, paddle_plan_id: "123")

      conn = get(conn, Routes.billing_path(conn, :choose_plan))
      assert redirected_to(conn) == Routes.billing_path(conn, :upgrade_to_enterprise_plan)
    end
  end

  describe "POST /change-plan" do
    setup [:create_user, :log_in]

    test "errors if usage exceeds team member limit on the new plan", %{conn: conn, user: user} do
      subscribe_to_plan(user, "123123")

      site = new_site(owner: user)

      for _ <- 1..4 do
        add_guest(site, role: :viewer)
      end

      conn = post(conn, Routes.billing_path(conn, :change_plan, @v4_growth_plan))

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Unable to subscribe to this plan because the following limits are exceeded: team member limit"
    end

    test "errors if usage exceeds site limit even when user.next_upgrade_override is true", %{
      conn: conn,
      user: user
    } do
      subscribe_to_plan(user, "123123")

      team =
        user
        |> team_of()
        |> Ecto.Changeset.change(allow_next_upgrade_override: true)
        |> Plausible.Repo.update!()

      for _ <- 1..11, do: new_site(owner: user)

      conn = post(conn, Routes.billing_path(conn, :change_plan, @v4_growth_plan))

      subscription = Plausible.Repo.get_by(Plausible.Billing.Subscription, team_id: team.id)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "are exceeded: site limit"
      assert subscription.paddle_plan_id == "123123"
    end

    test "can override allowing to upgrade when pageview limit is exceeded", %{
      conn: conn,
      user: user
    } do
      subscribe_to_plan(user, "123123")
      team = team_of(user)
      site = new_site(owner: user)
      now = NaiveDateTime.utc_now()

      generate_usage_for(site, 11_000, NaiveDateTime.shift(now, day: -5))
      generate_usage_for(site, 11_000, NaiveDateTime.shift(now, day: -35))

      conn1 = post(conn, Routes.billing_path(conn, :change_plan, @v4_growth_plan))

      subscription = Plausible.Repo.get_by(Plausible.Billing.Subscription, team_id: team.id)

      assert Phoenix.Flash.get(conn1.assigns.flash, :error) =~
               "are exceeded: monthly pageview limit"

      assert subscription.paddle_plan_id == "123123"

      user
      |> team_of()
      |> Ecto.Changeset.change(allow_next_upgrade_override: true)
      |> Plausible.Repo.update!()

      conn2 = post(conn, Routes.billing_path(conn, :change_plan, @v4_growth_plan))

      subscription = Plausible.Repo.reload!(subscription)

      assert Phoenix.Flash.get(conn2.assigns.flash, :success) =~ "Plan changed successfully"
      assert subscription.paddle_plan_id == @v4_growth_plan
    end

    test "calls Paddle API to update subscription", %{conn: conn, user: user} do
      subscribe_to_plan(user, "321321")
      team = team_of(user)

      post(conn, Routes.billing_path(conn, :change_plan, "123123"))

      subscription = Plausible.Repo.get_by(Plausible.Billing.Subscription, team_id: team.id)
      assert subscription.paddle_plan_id == "123123"
      assert subscription.next_bill_date == ~D[2019-07-10]
      assert subscription.next_bill_amount == "6.00"
    end
  end

  describe "GET /billing/upgrade-success" do
    setup [:create_user, :create_team, :log_in]

    test "shows success page after user subscribes", %{conn: conn} do
      conn = get(conn, Routes.billing_path(conn, :upgrade_success))

      assert html_response(conn, 200) =~ "Your account is being upgraded"
    end
  end

  @configured_enterprise_plan_paddle_plan_id "123"

  describe "GET /upgrade-to-enterprise-plan (no existing subscription)" do
    setup [:create_user, :log_in, :configure_enterprise_plan]

    test "displays basic page content", %{conn: conn} do
      doc =
        conn
        |> get(Routes.billing_path(conn, :upgrade_to_enterprise_plan))
        |> html_response(200)

      assert doc =~ "Upgrade to Enterprise"
      assert doc =~ "prepared a custom enterprise plan for your account with the following limits"
      assert doc =~ "Questions?"
      assert doc =~ "Contact us"
      assert doc =~ "+ VAT if applicable"
      assert doc =~ "Click the button below to upgrade"
      assert doc =~ "Pay securely via Paddle"
    end

    test "displays info about the enterprise plan to upgrade to", %{conn: conn} do
      doc =
        conn
        |> get(Routes.billing_path(conn, :upgrade_to_enterprise_plan))
        |> html_response(200)

      assert doc =~ ~r/Up to\s*<b>\s*50M\s*<\/b>\s*monthly pageviews/
      assert doc =~ ~r/Up to\s*<b>\s*20k\s*<\/b>\s*sites/
      assert doc =~ ~r/Up to\s*<b>\s*5k\s*<\/b>\s*hourly api requests/
      assert doc =~ ~r/The plan is priced at\s*<b>\s*€123\s*<\/b>\s*/
      assert doc =~ "per year"
    end

    test "data-product attribute on the checkout link is the paddle_plan_id of the enterprise plan",
         %{conn: conn, user: user} do
      {:ok, team} = Plausible.Teams.get_by_owner(user)

      doc =
        conn
        |> get(Routes.billing_path(conn, :upgrade_to_enterprise_plan))
        |> html_response(200)

      assert %{
               "disableLogout" => true,
               "email" => user.email,
               "passthrough" => "ee:#{ee?()};user:#{user.id};team:#{team.id}",
               "product" => @configured_enterprise_plan_paddle_plan_id,
               "success" => Routes.billing_path(PlausibleWeb.Endpoint, :upgrade_success),
               "theme" => "none"
             } == get_paddle_checkout_params(find(doc, "#paddle-button"))
    end
  end

  describe "GET /upgrade-to-enterprise-plan (active subscription, new enterprise plan configured)" do
    setup [:create_user, :log_in, :subscribe_enterprise, :configure_enterprise_plan]

    test "displays basic page content", %{conn: conn} do
      doc =
        conn
        |> get(Routes.billing_path(conn, :upgrade_to_enterprise_plan))
        |> html_response(200)

      assert doc =~ "Change subscription plan"
      assert doc =~ "prepared your account for an upgrade to custom limits"
      assert doc =~ "+ VAT if applicable"
      assert doc =~ "calculate the prorated amount that your card will be charged"
      assert doc =~ "Preview changes"
      assert doc =~ "Questions?"
      assert doc =~ "Contact us"
    end

    test "displays info about the enterprise plan to upgrade to", %{conn: conn} do
      doc =
        conn
        |> get(Routes.billing_path(conn, :upgrade_to_enterprise_plan))
        |> html_response(200)

      assert doc =~ ~r/Up to\s*<b>\s*50M\s*<\/b>\s*monthly pageviews/
      assert doc =~ ~r/Up to\s*<b>\s*20k\s*<\/b>\s*sites/
      assert doc =~ ~r/Up to\s*<b>\s*5k\s*<\/b>\s*hourly api requests/
      assert doc =~ ~r/The plan is priced at\s*<b>\s*€123\s*<\/b>\s*/
      assert doc =~ "per year"
    end

    test "preview changes links to :change_plan_preview action", %{conn: conn} do
      doc =
        conn
        |> get(Routes.billing_path(conn, :upgrade_to_enterprise_plan))
        |> html_response(200)

      preview_changes_link = find(doc, "#preview-changes")
      assert text(preview_changes_link) == "Preview changes"

      assert text_of_attr(preview_changes_link, "href") ==
               Routes.billing_path(
                 PlausibleWeb.Endpoint,
                 :change_plan_preview,
                 @configured_enterprise_plan_paddle_plan_id
               )
    end
  end

  describe "GET /billing/change-plan/preview/:plan_id" do
    setup [:create_user, :log_in]

    test "renders preview information about the plan change", %{conn: conn, user: user} do
      subscribe_to_plan(user, @v4_growth_plan)

      html_response =
        conn
        |> get(Routes.billing_path(conn, :change_plan_preview, @v4_business_plan))
        |> html_response(200)

      assert html_response =~
               "Your card will be charged a pro-rated amount for the current billing period"

      assert html_response =~ "€-72.6"
      assert html_response =~ "Back"
      assert html_response =~ ~s[<a href="/billing/choose-plan"]
    end

    test "flashes error and redirects to choose-plan page", %{conn: conn, user: user} do
      # choose-plan enforces at least 1 site, which implies team created, before allowing the user to upgrade
      new_site(owner: user)
      conn = get(conn, Routes.billing_path(conn, :change_plan_preview, @v4_business_plan))

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Something went wrong with loading your plan change information. Please try again, or contact us at support@plausible.io if the issue persists."

      assert redirected_to(conn) == Routes.billing_path(conn, :choose_plan)
    end
  end

  describe "GET /upgrade-to-enterprise-plan (already subscribed to latest enterprise plan)" do
    setup [:create_user, :log_in, :configure_enterprise_plan]

    setup context do
      subscribe_enterprise(context, paddle_plan_id: @configured_enterprise_plan_paddle_plan_id)
    end

    test "renders contact note", %{conn: conn} do
      doc =
        conn
        |> get(Routes.billing_path(conn, :upgrade_to_enterprise_plan))
        |> html_response(200)

      assert doc =~ "Looking to adjust your plan?"
      assert doc =~ "You're currently on a custom plan."
      assert Floki.text(doc) =~ "please contact us at hello@plausible.io"
    end
  end

  describe "GET /upgrade-to-enterprise-plan (subscription past_due or paused)" do
    setup [:create_user, :log_in, :configure_enterprise_plan]

    test "redirects to /settings when past_due", %{conn: conn} = context do
      subscribe_enterprise(context, status: Subscription.Status.past_due())
      conn = get(conn, Routes.billing_path(conn, :upgrade_to_enterprise_plan))
      assert redirected_to(conn) == Routes.settings_path(conn, :subscription)
    end

    test "redirects to /settings when paused", %{conn: conn} = context do
      subscribe_enterprise(context, status: Subscription.Status.paused())
      conn = get(conn, Routes.billing_path(conn, :upgrade_to_enterprise_plan))
      assert redirected_to(conn) == Routes.settings_path(conn, :subscription)
    end
  end

  describe "GET /upgrade-to-enterprise-plan (deleted enterprise subscription)" do
    setup [:create_user, :log_in, :configure_enterprise_plan]

    setup context do
      subscribe_enterprise(context,
        paddle_plan_id: @configured_enterprise_plan_paddle_plan_id,
        status: Subscription.Status.deleted()
      )

      context
    end

    test "displays the same content as for a user without a subscription", %{conn: conn} do
      doc =
        conn
        |> get(Routes.billing_path(conn, :upgrade_to_enterprise_plan))
        |> html_response(200)

      assert doc =~ "Upgrade to Enterprise"
      assert doc =~ "prepared a custom enterprise plan for your account with the following limits"
      assert doc =~ "Questions?"
      assert doc =~ "Contact us"
      assert doc =~ "+ VAT if applicable"
      assert doc =~ "Click the button below to upgrade"
      assert doc =~ "Pay securely via Paddle"
    end

    test "still allows to subscribe back to the same plan", %{conn: conn} do
      doc =
        conn
        |> get(Routes.billing_path(conn, :upgrade_to_enterprise_plan))
        |> html_response(200)

      assert doc =~ ~r/Up to\s*<b>\s*50M\s*<\/b>\s*monthly pageviews/
      assert doc =~ ~r/Up to\s*<b>\s*20k\s*<\/b>\s*sites/
      assert doc =~ ~r/Up to\s*<b>\s*5k\s*<\/b>\s*hourly api requests/
      assert doc =~ ~r/The plan is priced at\s*<b>\s*€123\s*<\/b>\s*/
      assert doc =~ "per year"
    end

    test "renders paddle button with the correct checkout params",
         %{conn: conn, user: user} do
      {:ok, team} = Plausible.Teams.get_by_owner(user)

      doc =
        conn
        |> get(Routes.billing_path(conn, :upgrade_to_enterprise_plan))
        |> html_response(200)

      assert %{
               "disableLogout" => true,
               "email" => user.email,
               "passthrough" => "ee:#{ee?()};user:#{user.id};team:#{team.id}",
               "product" => @configured_enterprise_plan_paddle_plan_id,
               "success" => Routes.billing_path(PlausibleWeb.Endpoint, :upgrade_success),
               "theme" => "none"
             } == get_paddle_checkout_params(find(doc, "#paddle-button"))
    end
  end

  defp configure_enterprise_plan(%{user: user}) do
    subscribe_to_enterprise_plan(user,
      paddle_plan_id: "123",
      billing_interval: :yearly,
      monthly_pageview_limit: 50_000_000,
      site_limit: 20_000,
      hourly_api_request_limit: 5000,
      inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.shift(hour: 1),
      subscription?: false
    )

    :ok
  end

  defp subscribe_enterprise(%{user: user}, opts \\ []) do
    {paddle_plan_id, opts} = Keyword.pop(opts, :paddle_plan_id, "321")

    opts = Keyword.put_new(opts, :status, Subscription.Status.active())

    user = subscribe_to_plan(user, paddle_plan_id, opts)

    {:ok, user: user}
  end

  defp get_paddle_checkout_params(element) do
    with onclick <- text_of_attr(element, "onclick"),
         [[_, checkout_params_str]] <- Regex.scan(~r/Paddle\.Checkout\.open\((.*?)\)/, onclick),
         {:ok, checkout_params} <- Jason.decode(checkout_params_str) do
      checkout_params
    end
  end
end
