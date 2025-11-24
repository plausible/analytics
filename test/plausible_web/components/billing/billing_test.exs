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
