defmodule PlausibleWeb.Components.BillingTest do
  use Plausible.DataCase
  use Plausible.Teams.Test
  import Phoenix.Component
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import Plausible.Test.Support.HTML

  describe "feature_gate/1" do
    setup [:create_user]

    test "renders a blur overlay if the feature is locked", %{user: user} do
      html =
        %{
          current_role: :owner,
          current_team: user |> subscribe_to_growth_plan() |> team_of(),
          locked?: true
        }
        |> render_feature_gate()

      assert class_of_element(html, "#feature-gate-inner-block-container") =~
               "pointer-events-none"

      assert class_of_element(html, "#feature-gate-overlay") =~ "backdrop-blur"
    end

    test "renders a blur overlay for a teamless account" do
      html =
        %{
          current_role: nil,
          current_team: nil,
          locked?: true
        }
        |> render_feature_gate()

      assert class_of_element(html, "#feature-gate-inner-block-container") =~
               "pointer-events-none"

      assert class_of_element(html, "#feature-gate-overlay") =~ "backdrop-blur"
    end

    test "does not render a blur overlay if feature access is granted", %{user: user} do
      html =
        %{
          current_role: :owner,
          current_team: user |> subscribe_to_business_plan() |> team_of(),
          locked?: false
        }
        |> render_feature_gate()

      refute class_of_element(html, "#feature-gate-inner-block-container") =~
               "pointer-events-none"

      refute class_of_element(html, "#feature-gate-overlay") =~ "backdrop-blur"
    end

    test "renders upgrade cta linking to the upgrade page if user role is :owner", %{user: user} do
      html =
        %{
          current_role: :owner,
          current_team: user |> subscribe_to_growth_plan() |> team_of(),
          locked?: true
        }
        |> render_feature_gate()

      assert text_of_element(html, "#lock-notice") =~ "upgrade your subscription"
    end

    test "renders upgrade cta linking to the upgrade page if user role is :billing", %{user: user} do
      html =
        %{
          current_role: :billing,
          current_team: user |> subscribe_to_growth_plan() |> team_of(),
          locked?: true
        }
        |> render_feature_gate()

      assert text_of_element(html, "#lock-notice") =~ "upgrade your subscription"
    end

    test "renders upgrade cta instructing to contact owner if user role is not :owner nor :billing",
         %{
           user: user
         } do
      html =
        %{
          current_role: :editor,
          current_team: user |> subscribe_to_growth_plan() |> team_of(),
          locked?: true
        }
        |> render_feature_gate()

      assert text_of_element(html, "#lock-notice") =~ "reach out to the team owner"
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
end
