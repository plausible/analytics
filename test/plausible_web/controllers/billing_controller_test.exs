defmodule PlausibleWeb.BillingControllerTest do
  use PlausibleWeb.ConnCase, async: true
  import Plausible.Test.Support.HTML

  describe "GET /upgrade" do
    setup [:create_user, :log_in]

    test "shows upgrade page when user does not have a subcription already", %{conn: conn} do
      conn = get(conn, "/billing/upgrade")

      assert html_response(conn, 200) =~ "Upgrade your free trial"
    end

    test "redirects user to change plan if they already have a plan", %{conn: conn, user: user} do
      insert(:subscription, user: user)
      conn = get(conn, "/billing/upgrade")

      assert redirected_to(conn) == "/billing/change-plan"
    end

    test "redirects user to enteprise plan page if they are configured with one", %{
      conn: conn,
      user: user
    } do
      plan = insert(:enterprise_plan, user: user)
      conn = get(conn, "/billing/upgrade")

      assert redirected_to(conn) == "/billing/upgrade/enterprise/#{plan.id}"
    end
  end

  describe "GET /upgrade/enterprise/:plan_id" do
    setup [:create_user, :log_in]

    test "renders enteprise plan upgrade page", %{conn: conn, user: user} do
      plan = insert(:enterprise_plan, user: user)

      conn = get(conn, "/billing/upgrade/enterprise/#{plan.id}")

      assert html_response(conn, 200) =~ "Upgrade your free trial"
      assert html_response(conn, 200) =~ "enterprise plan"
    end

    test "redirects to change-plan page if user is already subscribed to the given enterprise plan",
         %{conn: conn, user: user} do
      plan = insert(:enterprise_plan, user: user)
      insert(:subscription, paddle_plan_id: plan.paddle_plan_id, user: user)

      conn = get(conn, "/billing/upgrade/enterprise/#{plan.id}")

      assert redirected_to(conn) == "/billing/change-plan"
    end
  end

  describe "GET /change-plan" do
    setup [:create_user, :log_in]

    test "shows change plan page if user has subsription", %{conn: conn, user: user} do
      insert(:subscription, user: user)
      conn = get(conn, "/billing/change-plan")

      assert html_response(conn, 200) =~ "Change subscription plan"
    end

    test "redirects to /upgrade if user does not have a subscription", %{conn: conn} do
      conn = get(conn, "/billing/change-plan")

      assert redirected_to(conn) == "/billing/upgrade"
    end

    test "redirects to enterprise upgrade page if user is due for an enteprise plan upgrade",
         %{conn: conn, user: user} do
      insert(:subscription, user: user, paddle_plan_id: "standard-plan-id")
      enterprise_plan = insert(:enterprise_plan, user: user, paddle_plan_id: "new-custom-id")

      conn = get(conn, "/billing/change-plan")

      assert redirected_to(conn) == "/billing/change-plan/enterprise/#{enterprise_plan.id}"
    end

    test "prompts to contact us if user has enterprise plan and existing subscription",
         %{conn: conn, user: user} do
      insert(:subscription, user: user, paddle_plan_id: "enterprise-plan-id")
      insert(:enterprise_plan, user: user, paddle_plan_id: "enterprise-plan-id")

      conn = get(conn, "/billing/change-plan")

      assert html_response(conn, 200) =~ "please contact us"
    end
  end

  describe "GET /change-plan/enterprise/:plan_id" do
    setup [:create_user, :log_in]

    test "shows change plan page if user has subsription and enterprise plan", %{
      conn: conn,
      user: user
    } do
      insert(:subscription, user: user)

      plan =
        insert(:enterprise_plan,
          user: user,
          monthly_pageview_limit: 1000,
          hourly_api_request_limit: 500,
          site_limit: 100
        )

      conn = get(conn, "/billing/change-plan/enterprise/#{plan.id}")

      assert html_response(conn, 200) =~ "Change subscription plan"
      assert html_response(conn, 200) =~ "Up to <b>1k</b> monthly pageviews"
      assert html_response(conn, 200) =~ "Up to <b>500</b> hourly api requests"
      assert html_response(conn, 200) =~ "Up to <b>100</b> sites"
    end

    test "renders 404 is user does not have enterprise plan", %{conn: conn, user: user} do
      insert(:subscription, user: user)
      conn = get(conn, "/billing/change-plan/enterprise/123")

      assert conn.status == 404
    end
  end

  describe "POST /change-plan" do
    setup [:create_user, :log_in]

    test "calls Paddle API to update subscription", %{conn: conn, user: user} do
      insert(:subscription, user: user)

      post(conn, "/billing/change-plan/123123")

      subscription = Plausible.Repo.get_by(Plausible.Billing.Subscription, user_id: user.id)
      assert subscription.paddle_plan_id == "123123"
      assert subscription.next_bill_date == ~D[2019-07-10]
      assert subscription.next_bill_amount == "6.00"
    end
  end

  describe "GET /billing/upgrade-success" do
    setup [:create_user, :log_in]

    test "shows success page after user subscribes", %{conn: conn} do
      conn = get(conn, "/billing/upgrade-success")

      assert html_response(conn, 200) =~ "Your account is being upgraded"
    end
  end

  @configured_enterprise_plan_paddle_plan_id "123"

  describe "GET /upgrade-to-enterprise-plan (no existing subscription)" do
    setup [:create_user, :log_in, :configure_enterprise_plan]

    test "displays basic page content", %{conn: conn} do
      doc =
        conn
        |> get("/billing/upgrade-to-enterprise-plan")
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
        |> get("/billing/upgrade-to-enterprise-plan")
        |> html_response(200)

      assert doc =~ ~r/Up to\s*<b>\s*50M\s*<\/b>\s*monthly pageviews/
      assert doc =~ ~r/Up to\s*<b>\s*20k\s*<\/b>\s*sites/
      assert doc =~ ~r/Up to\s*<b>\s*5k\s*<\/b>\s*hourly api requests/
      assert doc =~ ~r/The plan is priced at\s*<b>\s*€10\s*<\/b>\s*/
      assert doc =~ "per year"
    end

    test "data-product attribute on the checkout link is the paddle_plan_id of the enterprise plan",
         %{conn: conn, user: user} do
      doc =
        conn
        |> get("/billing/upgrade-to-enterprise-plan")
        |> html_response(200)

      assert %{
               "disableLogout" => true,
               "email" => user.email,
               "passthrough" => user.id,
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
        |> get("/billing/upgrade-to-enterprise-plan")
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
        |> get("/billing/upgrade-to-enterprise-plan")
        |> html_response(200)

      assert doc =~ ~r/Up to\s*<b>\s*50M\s*<\/b>\s*monthly pageviews/
      assert doc =~ ~r/Up to\s*<b>\s*20k\s*<\/b>\s*sites/
      assert doc =~ ~r/Up to\s*<b>\s*5k\s*<\/b>\s*hourly api requests/
      assert doc =~ ~r/The plan is priced at\s*<b>\s*€10\s*<\/b>\s*/
      assert doc =~ "per year"
    end

    test "preview changes links to :change_plan_preview action", %{conn: conn} do
      doc =
        conn
        |> get("/billing/upgrade-to-enterprise-plan")
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

  @enterprise_contact_link "enterprise@plausible.io"

  describe "GET /upgrade-to-enterprise-plan (already subscribed to latest enterprise plan)" do
    setup [:create_user, :log_in, :configure_enterprise_plan]

    setup context do
      subscribe_enterprise(context, paddle_plan_id: @configured_enterprise_plan_paddle_plan_id)
    end

    test "renders contact note", %{conn: conn} do
      doc =
        conn
        |> get("/billing/upgrade-to-enterprise-plan")
        |> html_response(200)

      assert doc =~ "Need to change your limits?"
      assert doc =~ "Your account is on an enterprise plan"
      assert doc =~ "contact us at #{@enterprise_contact_link}"
    end
  end

  describe "GET /upgrade-to-enterprise-plan (subscription past_due or paused)" do
    setup [:create_user, :log_in, :configure_enterprise_plan]

    test "redirects to /settings when past_due", %{conn: conn} = context do
      subscribe_enterprise(context, status: "past_due")
      conn = get(conn, "/billing/upgrade-to-enterprise-plan")
      assert redirected_to(conn) == "/settings"
    end

    test "redirects to /settings when paused", %{conn: conn} = context do
      subscribe_enterprise(context, status: "paused")
      conn = get(conn, "/billing/upgrade-to-enterprise-plan")
      assert redirected_to(conn) == "/settings"
    end
  end

  describe "GET /upgrade-to-enterprise-plan (deleted enterprise subscription)" do
    setup [:create_user, :log_in, :configure_enterprise_plan]

    setup context do
      subscribe_enterprise(context,
        paddle_plan_id: @configured_enterprise_plan_paddle_plan_id,
        status: "deleted"
      )

      context
    end

    test "displays the same content as for a user without a subscription", %{conn: conn} do
      doc =
        conn
        |> get("/billing/upgrade-to-enterprise-plan")
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
        |> get("/billing/upgrade-to-enterprise-plan")
        |> html_response(200)

      assert doc =~ ~r/Up to\s*<b>\s*50M\s*<\/b>\s*monthly pageviews/
      assert doc =~ ~r/Up to\s*<b>\s*20k\s*<\/b>\s*sites/
      assert doc =~ ~r/Up to\s*<b>\s*5k\s*<\/b>\s*hourly api requests/
      assert doc =~ ~r/The plan is priced at\s*<b>\s*€10\s*<\/b>\s*/
      assert doc =~ "per year"
    end

    test "renders paddle button with the correct checkout params",
         %{conn: conn, user: user} do
      doc =
        conn
        |> get("/billing/upgrade-to-enterprise-plan")
        |> html_response(200)

      assert %{
               "disableLogout" => true,
               "email" => user.email,
               "passthrough" => user.id,
               "product" => @configured_enterprise_plan_paddle_plan_id,
               "success" => Routes.billing_path(PlausibleWeb.Endpoint, :upgrade_success),
               "theme" => "none"
             } == get_paddle_checkout_params(find(doc, "#paddle-button"))
    end
  end

  defp configure_enterprise_plan(%{user: user}) do
    insert(:enterprise_plan,
      user_id: user.id,
      paddle_plan_id: "123",
      billing_interval: :yearly,
      monthly_pageview_limit: 50_000_000,
      site_limit: 20000,
      hourly_api_request_limit: 5000,
      inserted_at: Timex.now() |> Timex.shift(hours: 1)
    )

    :ok
  end

  defp subscribe_enterprise(%{user: user}, opts \\ []) do
    opts =
      opts
      |> Keyword.put(:user, user)
      |> Keyword.put_new(:paddle_plan_id, "321")
      |> Keyword.put_new(:status, "active")

    insert(:subscription, opts)

    {:ok, user: Plausible.Users.with_subscription(user)}
  end

  defp get_paddle_checkout_params(element) do
    with onclick <- text_of_attr(element, "onclick"),
         [[_, checkout_params_str]] <- Regex.scan(~r/Paddle\.Checkout\.open\((.*?)\)/, onclick),
         {:ok, checkout_params} <- Jason.decode(checkout_params_str) do
      checkout_params
    end
  end
end
