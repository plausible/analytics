defmodule Plausible.Teams.Sites.TransferTest do
  use Plausible
  require Plausible.Billing.Subscription.Status
  use Plausible.DataCase, async: true
  use Bamboo.Test
  use Plausible.Teams.Test

  alias Plausible.Teams.Sites.Transfer

  @subject_prefix if ee?(), do: "[Plausible Analytics] ", else: "[Plausible CE] "

  describe "change_team/3" do
    @tag :ce_build_only
    test "changes the team if owner in both teams (CE)" do
      user = new_user()
      site = new_site(owner: user)

      another = new_user()
      new_site(owner: another)

      team2 = team_of(another)

      add_member(team2, user: user, role: :owner)

      assert :ok = Transfer.change_team(site, user, team2)
    end

    @tag :ee_only
    test "changes the team if owner in both teams (EE)" do
      user = new_user()
      site = new_site(owner: user)

      another = new_user()
      new_site(owner: another)

      team2 = team_of(another)

      add_member(team2, user: user, role: :owner)

      assert {:error, :no_plan} = Transfer.change_team(site, user, team2)

      subscribe_to_growth_plan(another)

      assert :ok = Transfer.change_team(site, user, team2)
      assert Repo.reload!(site).team_id == team2.id
      assert_team_membership(user, team2, :owner)

      assert_email_delivered_with(
        to: [nil: another.email],
        subject:
          @subject_prefix <>
            "#{user.email} has transferred #{site.domain} to \"#{team2.name}\" team"
      )

      assert_email_delivered_with(
        to: [nil: user.email],
        subject:
          @subject_prefix <>
            "#{user.email} has transferred #{site.domain} to \"#{team2.name}\" team"
      )
    end

    test "changes the team if admin in second team" do
      user = new_user()
      site = new_site(owner: user)

      another = new_user()
      subscribe_to_growth_plan(another)
      new_site(owner: another)

      team2 = team_of(another)

      add_member(team2, user: user, role: :admin)

      assert :ok = Transfer.change_team(site, user, team2)
      assert Repo.reload!(site).team_id == team2.id
      assert_team_membership(user, team2, :admin)

      assert_email_delivered_with(
        to: [nil: another.email],
        subject:
          @subject_prefix <>
            "#{user.email} has transferred #{site.domain} to \"#{team2.name}\" team"
      )
    end

    for role <- Plausible.Teams.Membership.roles() -- [:admin, :owner] do
      test "refuses to change the team if #{role} in second team" do
        user = new_user()
        site = new_site(owner: user)

        another = new_user()
        subscribe_to_growth_plan(another)
        new_site(owner: another)

        team2 = team_of(another)

        add_member(team2, user: user, role: unquote(role))

        assert {:error, :permission_denied} = Transfer.change_team(site, user, team2)
        refute Repo.reload!(site).team_id == team2.id
      end
    end
  end
end
