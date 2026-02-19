defmodule PlausibleWeb.Components.BillingTest do
  use Plausible.DataCase
  import Phoenix.Component
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  describe "feature_gate/1" do
    setup [:create_user]

    test "renders a blur overlay if the feature is locked", %{user: user} do
      html =
        %{
          current_user: user,
          current_team: user |> subscribe_to_growth_plan() |> team_of(),
          locked?: true
        }
        |> render_feature_gate()

      assert element_exists?(html, "#feature-gate-inner-block-container")
      assert element_exists?(html, "#feature-gate-overlay")
      assert text_of_element(html, "#feature-gate-overlay") =~ "Upgrade to unlock"
    end

    test "renders a blur overlay for a teamless account", %{user: user} do
      html =
        %{
          current_user: user,
          current_team: nil,
          locked?: true
        }
        |> render_feature_gate()

      assert element_exists?(html, "#feature-gate-inner-block-container")
      assert element_exists?(html, "#feature-gate-overlay")
      assert text_of_element(html, "#feature-gate-overlay") =~ "Upgrade to unlock"
    end

    test "does not render a blur overlay if feature access is granted", %{user: user} do
      html =
        %{
          current_user: user,
          current_team: user |> subscribe_to_business_plan() |> team_of(),
          locked?: false
        }
        |> render_feature_gate()

      assert element_exists?(html, "#feature-gate-inner-block-container")
      refute element_exists?(html, "#feature-gate-overlay")
    end

    test "renders upgrade cta linking to the upgrade page if user role is :owner", %{user: user} do
      html =
        %{
          current_user: user,
          current_team: user |> subscribe_to_growth_plan() |> team_of(),
          locked?: true
        }
        |> render_feature_gate()

      assert text_of_element(html, "#lock-notice") =~ "upgrade your subscription"
    end

    test "renders upgrade cta linking to the upgrade page if user role is :billing", %{user: user} do
      team = user |> subscribe_to_growth_plan() |> team_of()
      billing = add_member(team, role: :billing)

      html =
        %{
          current_user: billing,
          current_team: team,
          locked?: true
        }
        |> render_feature_gate()

      assert text_of_element(html, "#lock-notice") =~ "upgrade your subscription"
    end

    test "renders upgrade cta instructing to contact owner if user role is not :owner nor :billing",
         %{
           user: user
         } do
      team = user |> subscribe_to_growth_plan() |> team_of()
      editor = add_member(team, role: :editor)

      html =
        %{
          current_user: editor,
          current_team: team,
          locked?: true
        }
        |> render_feature_gate()

      assert text_of_element(html, "#lock-notice") =~ "ask your team owner"
    end

    test "renders upgrade cta linking to the upgrade page when user is not a team member (e.g. super-admin)",
         %{
           user: user
         } do
      team = user |> subscribe_to_growth_plan() |> team_of()
      other_user = new_user()

      html =
        %{
          current_user: other_user,
          current_team: team,
          locked?: true
        }
        |> render_feature_gate()

      assert text_of_element(html, "#lock-notice") =~ "upgrade your subscription"
    end
  end

  defp render_feature_gate(assigns) do
    ~H"""
    <PlausibleWeb.Components.Billing.feature_gate {assigns}>
      <div>content...</div>
    </PlausibleWeb.Components.Billing.feature_gate>
    """
    |> rendered_to_string()
  end

  describe "usage_progress_bar/1" do
    test "renders progress bar with green color at 0% usage" do
      html = render_progress_bar(0, 10_000)

      assert html =~ "width: 0"
      assert html =~ "bg-green-500 dark:bg-green-600"
    end

    test "renders progress bar with green color at 50% usage" do
      html = render_progress_bar(5_000, 10_000)

      assert html =~ "width: 50.0%"
      assert html =~ "bg-green-500 dark:bg-green-600"
    end

    test "renders progress bar with green color at 90% usage" do
      html = render_progress_bar(9_000, 10_000)

      assert html =~ "width: 90.0%"
      assert html =~ "bg-green-500 dark:bg-green-600"
    end

    test "renders progress bar with gradient at 95% usage" do
      html = render_progress_bar(9_500, 10_000)

      assert html =~ "width: 95.0%"
      assert html =~ "bg-gradient-to-r from-green-500 via-yellow-500 via-[80%] to-orange-500"
    end

    test "renders progress bar with red gradient at 100% usage" do
      html = render_progress_bar(10_000, 10_000)

      assert html =~ "width: 100.0%"
      assert html =~ "bg-gradient-to-r from-green-500 via-orange-500 via-[80%] to-red-500"
    end

    test "caps percentage at 100% when usage exceeds limit" do
      html = render_progress_bar(15_000, 10_000)

      assert html =~ "width: 100.0%"
      assert html =~ "bg-gradient-to-r from-green-500 via-orange-500 via-[80%] to-red-500"
    end

    test "handles unlimited limit" do
      html = render_progress_bar(5_000, :unlimited)

      assert html =~ "width: 0%"
      assert html =~ "bg-green-500 dark:bg-green-600"
    end

    test "handles zero limit" do
      html = render_progress_bar(0, 0)

      assert html =~ "width: 0%"
      assert html =~ "bg-gray-200 dark:bg-gray-700"
    end
  end

  describe "render_monthly_pageview_usage/1" do
    @cycle %{
      pageviews: 0,
      custom_events: 0,
      total: 0,
      date_range: Date.range(~D[2024-01-01], ~D[2024-01-31])
    }

    test "only shows current cycle when neither last nor current cycle is exceeded" do
      usage = %{
        current_cycle: @cycle,
        last_cycle: @cycle,
        penultimate_cycle: @cycle
      }

      html = render_monthly_pageview_usage(usage, 10_000)

      assert element_exists?(html, "#total_pageviews_current_cycle")
      refute element_exists?(html, "#total_pageviews_last_cycle")
      refute element_exists?(html, "#total_pageviews_penultimate_cycle")
    end

    test "shows all three cycles when last cycle is exceeded" do
      usage = %{
        current_cycle: @cycle,
        last_cycle: %{@cycle | total: 11_000},
        penultimate_cycle: @cycle
      }

      html = render_monthly_pageview_usage(usage, 10_000)

      assert element_exists?(html, "#total_pageviews_current_cycle")
      assert element_exists?(html, "#total_pageviews_last_cycle")
      assert element_exists?(html, "#total_pageviews_penultimate_cycle")
    end

    test "shows all three cycles when current cycle is exceeded" do
      usage = %{
        current_cycle: %{@cycle | total: 11_000},
        last_cycle: @cycle,
        penultimate_cycle: @cycle
      }

      html = render_monthly_pageview_usage(usage, 10_000)

      assert element_exists?(html, "#total_pageviews_current_cycle")
      assert element_exists?(html, "#total_pageviews_last_cycle")
      assert element_exists?(html, "#total_pageviews_penultimate_cycle")
    end

    test "shows all three cycles when both last and current cycles are exceeded" do
      usage = %{
        current_cycle: %{@cycle | total: 11_000},
        last_cycle: %{@cycle | total: 11_000},
        penultimate_cycle: @cycle
      }

      html = render_monthly_pageview_usage(usage, 10_000)

      assert element_exists?(html, "#total_pageviews_current_cycle")
      assert element_exists?(html, "#total_pageviews_last_cycle")
      assert element_exists?(html, "#total_pageviews_penultimate_cycle")
    end
  end

  defp render_progress_bar(usage, limit) do
    assigns = %{usage: usage, limit: limit}

    ~H"""
    <PlausibleWeb.Components.Billing.usage_progress_bar
      usage={@usage}
      limit={@limit}
    />
    """
    |> rendered_to_string()
  end

  defp render_monthly_pageview_usage(usage, limit) do
    assigns = %{usage: usage, limit: limit}

    ~H"""
    <PlausibleWeb.Components.Billing.render_monthly_pageview_usage
      usage={@usage}
      limit={@limit}
    />
    """
    |> rendered_to_string()
  end
end
