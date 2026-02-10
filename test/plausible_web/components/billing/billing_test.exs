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

  describe "usage_progress_row/1" do
    test "renders progress bar with green color at 0% usage" do
      html = render_progress_row(0, 10_000)

      assert html =~ "0"
      assert html =~ "10,000"
      assert html =~ "width: 0"
      assert html =~ "bg-green-500 dark:bg-green-600"
    end

    test "renders progress bar with green color at 50% usage" do
      html = render_progress_row(5_000, 10_000)

      assert html =~ "5,000"
      assert html =~ "10,000"
      assert html =~ "width: 50.0%"
      assert html =~ "bg-green-500 dark:bg-green-600"
    end

    test "renders progress bar with green color at 90% usage" do
      html = render_progress_row(9_000, 10_000)

      assert html =~ "9,000"
      assert html =~ "10,000"
      assert html =~ "width: 90.0%"
      assert html =~ "bg-green-500 dark:bg-green-600"
    end

    test "renders progress bar with gradient at 95% usage" do
      html = render_progress_row(9_500, 10_000)

      assert html =~ "9,500"
      assert html =~ "10,000"
      assert html =~ "width: 95.0%"
      assert html =~ "bg-gradient-to-r from-green-500 via-yellow-500 via-[80%] to-orange-500"
    end

    test "renders progress bar with red gradient at 100% usage" do
      html = render_progress_row(10_000, 10_000)

      assert html =~ "10,000"
      assert html =~ "width: 100.0%"
      assert html =~ "bg-gradient-to-r from-green-500 via-orange-500 via-[80%] to-red-500"
    end

    test "caps percentage at 100% when usage exceeds limit" do
      html = render_progress_row(15_000, 10_000)

      assert html =~ "15,000"
      assert html =~ "10,000"
      assert html =~ "width: 100.0%"
      assert html =~ "bg-gradient-to-r from-green-500 via-orange-500 via-[80%] to-red-500"
    end

    test "handles unlimited limit" do
      html = render_progress_row(5_000, :unlimited)

      assert html =~ "5,000"
      assert html =~ "Unlimited"
      assert html =~ "width: 0%"
      assert html =~ "bg-green-500 dark:bg-green-600"
    end

    test "handles zero limit" do
      html = render_progress_row(0, 0)

      assert html =~ "0"
      assert html =~ "width: 0%"
      assert html =~ "bg-gray-200 dark:bg-gray-700"
    end

    test "includes title in output" do
      html = render_progress_row(100, 1000, "Test title")

      assert html =~ "Test title"
    end
  end

  defp render_progress_row(usage, limit, title \\ "Pageviews") do
    assigns = %{title: title, usage: usage, limit: limit}

    ~H"""
    <PlausibleWeb.Components.Billing.usage_progress_row
      title={@title}
      usage={@usage}
      limit={@limit}
    />
    """
    |> rendered_to_string()
  end
end
