defmodule Plausible.Teams.Sites.TransferTest do
  use Plausible.DataCase, async: true
  use Bamboo.Test

  alias Plausible.Teams.Sites.Transfer

  @subject_prefix if ee?(), do: "[Plausible Analytics] ", else: "[Plausible CE] "

  describe "initiate/3" do
    test "sends ownership transfer email" do
      inviter = new_user()
      site = new_site(owner: inviter)

      assert {:ok, %Plausible.Teams.SiteTransfer{}} =
               Transfer.initiate(site, inviter, "vini@plausible.test")

      assert_email_delivered_with(
        to: [nil: "vini@plausible.test"],
        subject: @subject_prefix <> "Request to transfer ownership of #{site.domain}"
      )
    end

    test "admin can initiate ownership transfer too" do
      inviter = new_user()
      site = new_site()
      add_member(site.team, user: inviter, role: :admin)

      assert {:ok, %Plausible.Teams.SiteTransfer{}} =
               Transfer.initiate(site, inviter, "vini@plausible.test")

      assert_email_delivered_with(
        to: [nil: "vini@plausible.test"],
        subject: @subject_prefix <> "Request to transfer ownership of #{site.domain}"
      )
    end

    test "only allows owners and admins to transfer ownership" do
      inviter = new_user()

      site = new_site()
      add_guest(site, user: inviter, role: :editor)

      assert {:error, :permission_denied} =
               Transfer.initiate(site, inviter, "vini@plausible.test")
    end

    test "allows ownership transfer to existing site members" do
      inviter = new_user()
      invitee = new_user()
      site = new_site(owner: inviter)
      add_guest(site, user: invitee, role: :viewer)

      assert {:ok, %Plausible.Teams.SiteTransfer{}} =
               Transfer.initiate(site, inviter, invitee.email)
    end

    test "sends the email again when the same transfer already exists" do
      inviter = new_user()
      site = new_site(owner: inviter)

      email = "vini@plausible.test"

      assert {:ok, transfer} = Transfer.initiate(site, inviter, email)

      assert_email_delivered_with(
        to: [nil: email],
        subject: @subject_prefix <> "Request to transfer ownership of #{site.domain}"
      )

      assert {:ok, resent} = Transfer.initiate(site, inviter, email)

      assert_email_delivered_with(
        to: [nil: email],
        subject: @subject_prefix <> "Request to transfer ownership of #{site.domain}"
      )

      assert resent.transfer_id == transfer.transfer_id
    end

    test "allows creating an ownership transfer even when at team member limit" do
      inviter = new_user()
      site = new_site(owner: inviter)
      for _ <- 1..3, do: add_guest(site, role: :viewer)

      assert {:ok, _invitation} =
               Transfer.initiate(site, inviter, "newowner@plausible.test")
    end
  end

  describe "create_site_transfer/4" do
    test "returns the existing transfer and sets its updated_at to now" do
      inviter = new_user()
      site = new_site(owner: inviter)

      {:ok, transfer} = Transfer.create_site_transfer(site, inviter, "vini@plausible.test")

      later = ~N[2026-01-02 00:00:00]

      assert {:ok, resent} =
               Transfer.create_site_transfer(site, inviter, "vini@plausible.test", later)

      assert resent.id == transfer.id
      assert resent.transfer_id == transfer.transfer_id
      assert resent.updated_at == later
    end
  end

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

    on_ee do
      alias Plausible.ConsolidatedView

      test "disables consolidated view if sites transferred out of team" do
        user = new_user()
        site = new_site(owner: user)
        new_site(owner: user)
        team = team_of(user)

        new_consolidated_view(team)
        assert ConsolidatedView.get(team)

        another_owner = new_user()
        subscribe_to_growth_plan(another_owner)
        _ = new_site(owner: another_owner)
        another_team = team_of(another_owner)

        add_member(another_team, user: user, role: :owner)

        :ok = Transfer.change_team(site, user, another_team)

        refute ConsolidatedView.get(team)
      end
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
