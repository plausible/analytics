defmodule PlausibleWeb.Team.NoticeTest do
  use Plausible.DataCase, async: true
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias PlausibleWeb.Team.Notice

  describe "team_invitations/1" do
    test "renders nothing when list is empty" do
      rendered = render_component(&Notice.team_invitations/1, team_invitations: [])

      assert rendered == ""
    end

    test "renders inviter name, team name and role" do
      invitations = [
        %{
          invitation_id: "inv-1",
          inviter: %{name: "Alice"},
          team: %{name: "Acme Corp"},
          role: :admin
        }
      ]

      rendered = render_component(&Notice.team_invitations/1, team_invitations: invitations)

      assert rendered =~ "Alice"
      assert rendered =~ "Acme Corp"
      assert rendered =~ "admin"
    end

    test "renders accept and reject links for each invitation" do
      invitations = [
        %{
          invitation_id: "inv-abc",
          inviter: %{name: "Bob"},
          team: %{name: "Team X"},
          role: :viewer
        }
      ]

      rendered = render_component(&Notice.team_invitations/1, team_invitations: invitations)

      assert rendered =~ ~r{href="[^"]*invitations/inv-abc/accept"}
      assert rendered =~ ~r{href="[^"]*invitations/inv-abc/reject"}
    end

    test "renders one notice per invitation" do
      invitations = [
        %{invitation_id: "inv-1", inviter: %{name: "A"}, team: %{name: "T1"}, role: :viewer},
        %{invitation_id: "inv-2", inviter: %{name: "B"}, team: %{name: "T2"}, role: :admin}
      ]

      rendered = render_component(&Notice.team_invitations/1, team_invitations: invitations)

      assert rendered =~ "T1"
      assert rendered =~ "T2"
      assert rendered =~ ~r{href="[^"]*invitations/inv-1/accept"}
      assert rendered =~ ~r{href="[^"]*invitations/inv-2/accept"}
    end
  end

  describe "site_invitations/1" do
    test "renders nothing when list is empty" do
      rendered = render_component(&Notice.site_invitations/1, site_invitations: [])

      assert rendered == ""
    end

    test "renders inviter name, site domain and role" do
      invitations = [
        %{
          invitation_id: "gi-1",
          team_invitation: %{inviter: %{name: "Carol"}},
          site: %{domain: "example.com"},
          role: :viewer
        }
      ]

      rendered = render_component(&Notice.site_invitations/1, site_invitations: invitations)

      assert rendered =~ "Carol"
      assert rendered =~ "example.com"
      assert rendered =~ "viewer"
    end

    test "renders accept and reject links" do
      invitations = [
        %{
          invitation_id: "gi-xyz",
          team_invitation: %{inviter: %{name: "Dan"}},
          site: %{domain: "mysite.io"},
          role: :editor
        }
      ]

      rendered = render_component(&Notice.site_invitations/1, site_invitations: invitations)

      assert rendered =~ ~r{href="[^"]*invitations/gi-xyz/accept"}
      assert rendered =~ ~r{href="[^"]*invitations/gi-xyz/reject"}
    end
  end

  describe "site_ownership_invitations/1" do
    test "renders nothing when list is empty" do
      rendered =
        render_component(&Notice.site_ownership_invitations/1,
          site_ownership_invitations: [],
          current_team: nil
        )

      assert rendered == ""
    end

    test "renders initiator name and site domain" do
      transfers = [
        %{
          transfer_id: "tr-1",
          initiator: %{name: "Eve"},
          site: %{domain: "transfer.me"},
          ownership_check: :ok
        }
      ]

      rendered =
        render_component(&Notice.site_ownership_invitations/1,
          site_ownership_invitations: transfers,
          current_team: nil
        )

      assert rendered =~ "Eve"
      assert rendered =~ "transfer.me"
    end

    test "renders accept and reject links when ownership check passes" do
      transfers = [
        %{
          transfer_id: "tr-abc",
          initiator: %{name: "Eve"},
          site: %{domain: "transfer.me"},
          ownership_check: :ok
        }
      ]

      rendered =
        render_component(&Notice.site_ownership_invitations/1,
          site_ownership_invitations: transfers,
          current_team: nil
        )

      assert rendered =~ ~r{href="[^"]*invitations/tr-abc/accept"}
      assert rendered =~ ~r{href="[^"]*invitations/tr-abc/reject"}
      refute rendered =~ "/billing/choose-plan"
    end

    test "shows current team name in billing note when ownership check passes" do
      transfers = [
        %{
          transfer_id: "tr-team",
          initiator: %{name: "Eve"},
          site: %{domain: "transfer.me"},
          ownership_check: :ok
        }
      ]

      rendered =
        render_component(&Notice.site_ownership_invitations/1,
          site_ownership_invitations: transfers,
          current_team: %Plausible.Teams.Team{name: "My Team", setup_complete: true}
        )

      assert rendered =~ "My Team"
      assert rendered =~ "billing"
    end

    test "renders upgrade link and no accept link when there is no plan" do
      transfers = [
        %{
          transfer_id: "tr-noplan",
          initiator: %{name: "Frank"},
          site: %{domain: "nope.io"},
          ownership_check: {:error, :no_plan}
        }
      ]

      rendered =
        render_component(&Notice.site_ownership_invitations/1,
          site_ownership_invitations: transfers,
          current_team: nil
        )

      assert rendered =~ "/billing/choose-plan"
      refute rendered =~ ~r{href="[^"]*invitations/tr-noplan/accept"}
      assert rendered =~ ~r{href="[^"]*invitations/tr-noplan/reject"}
      assert rendered =~ "You don't have an active subscription"
    end

    test "renders upgrade link and no accept link when plan limits are exceeded" do
      transfers = [
        %{
          transfer_id: "tr-over",
          initiator: %{name: "Grace"},
          site: %{domain: "big.io"},
          ownership_check: {:error, {:over_plan_limits, [:site_limit]}}
        }
      ]

      rendered =
        render_component(&Notice.site_ownership_invitations/1,
          site_ownership_invitations: transfers,
          current_team: nil
        )

      assert rendered =~ "/billing/choose-plan"
      refute rendered =~ ~r{href="[^"]*invitations/tr-over/accept"}
      assert rendered =~ ~r{href="[^"]*invitations/tr-over/reject"}
      assert rendered =~ "exceeds your current"
      assert rendered =~ "site limit"
    end
  end
end
