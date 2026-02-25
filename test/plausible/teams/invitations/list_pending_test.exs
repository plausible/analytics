defmodule Plausible.Teams.Invitations.ListPendingTest do
  use Plausible.DataCase, async: true

  alias Plausible.Teams.Invitations

  describe "pending_team_invitations_for/1" do
    test "returns non-guest team invitations for the user" do
      inviter = new_user(name: "Alice")
      _site = new_site(owner: inviter)
      team = team_of(inviter)
      invitee = new_user()

      invitation = invite_member(team, invitee, inviter: inviter, role: :admin)

      results = Invitations.pending_team_invitations_for(invitee)

      assert [ti] = results
      assert ti.invitation_id == invitation.invitation_id
      assert ti.role == :admin
      assert ti.inviter.name == "Alice"
      assert ti.team.id == team.id
    end

    test "does not return guest-role team invitations" do
      inviter = new_user()
      site = new_site(owner: inviter)
      invitee = new_user()

      invite_guest(site, invitee, inviter: inviter, role: :viewer)

      assert Invitations.pending_team_invitations_for(invitee) == []
    end

    test "returns multiple invitations from different teams" do
      inviter1 = new_user(name: "Dave")
      inviter2 = new_user(name: "Eve")
      _site1 = new_site(owner: inviter1)
      _site2 = new_site(owner: inviter2)
      team1 = team_of(inviter1)
      team2 = team_of(inviter2)
      invitee = new_user()

      inv1 = invite_member(team1, invitee, inviter: inviter1, role: :viewer)
      inv2 = invite_member(team2, invitee, inviter: inviter2, role: :admin)

      results = Invitations.pending_team_invitations_for(invitee)

      assert length(results) == 2
      ids = Enum.map(results, & &1.invitation_id)
      assert inv1.invitation_id in ids
      assert inv2.invitation_id in ids
    end

    test "does not return invitations for other users" do
      inviter = new_user()
      _site = new_site(owner: inviter)
      team = team_of(inviter)
      other_user = new_user()

      invite_member(team, other_user, inviter: inviter, role: :admin)

      assert Invitations.pending_team_invitations_for(new_user()) == []
    end
  end

  describe "pending_guest_invitations_for/1" do
    test "returns guest invitations with site and inviter preloaded" do
      inviter = new_user(name: "Bob")
      site = new_site(owner: inviter)
      invitee = new_user()

      gi = invite_guest(site, invitee, inviter: inviter, role: :viewer)

      results = Invitations.pending_guest_invitations_for(invitee)

      assert [entry] = results
      assert entry.invitation_id == gi.invitation_id
      assert entry.role == :viewer
      assert entry.site.id == site.id
      assert entry.team_invitation.inviter.name == "Bob"
    end

    test "returns editor role as-is (role mapping is a UI concern)" do
      inviter = new_user()
      site = new_site(owner: inviter)
      invitee = new_user()

      gi = invite_guest(site, invitee, inviter: inviter, role: :editor)

      [entry] = Invitations.pending_guest_invitations_for(invitee)
      assert entry.invitation_id == gi.invitation_id
      assert entry.role == :editor
    end

    test "does not return invitations for other users" do
      inviter = new_user()
      site = new_site(owner: inviter)
      other_user = new_user()

      invite_guest(site, other_user, inviter: inviter, role: :viewer)

      assert Invitations.pending_guest_invitations_for(new_user()) == []
    end

    test "does not return invitation if invitee is already a full team member" do
      inviter = new_user()
      site = new_site(owner: inviter)
      invitee = new_user()

      invite_guest(site, invitee, inviter: inviter, role: :viewer)
      add_member(site.team, user: invitee, role: :editor)

      assert Invitations.pending_guest_invitations_for(invitee) == []
    end

    test "does not return invitation if invitee is already a guest member of that site" do
      inviter = new_user()
      site = new_site(owner: inviter)
      invitee = new_user()

      invite_guest(site, invitee, inviter: inviter, role: :viewer)
      add_guest(site, user: invitee, role: :viewer)

      assert Invitations.pending_guest_invitations_for(invitee) == []
    end

    test "returns invitations to multiple sites within single team" do
      inviter = new_user()
      site1 = new_site(owner: inviter)
      site2 = new_site(owner: inviter)
      invitee = new_user()

      gi1 =
        site1
        |> invite_guest(invitee, inviter: inviter, role: :viewer)
        |> Plausible.Repo.preload(:team_invitation)

      gi2 =
        insert(:guest_invitation,
          site: site2,
          team_invitation: gi1.team_invitation,
          role: :editor
        )

      results = Invitations.pending_guest_invitations_for(invitee)

      assert length(results) == 2
      ids = Enum.map(results, & &1.invitation_id)
      assert gi1.invitation_id in ids
      assert gi2.invitation_id in ids
    end
  end

  describe "pending_site_transfers_for/1" do
    test "returns site transfer with site and initiator preloaded" do
      initiator = new_user(name: "Carol")
      site = new_site(owner: initiator)
      invitee = new_user()

      transfer = invite_transfer(site, invitee, inviter: initiator)

      results = Invitations.pending_site_transfers_for(invitee)

      assert [entry] = results
      assert entry.transfer_id == transfer.transfer_id
      assert entry.site.id == site.id
      assert entry.initiator.name == "Carol"
    end

    test "returns transfers from multiple sites" do
      initiator = new_user()
      site1 = new_site(owner: initiator)
      site2 = new_site(owner: initiator)
      invitee = new_user()

      t1 = invite_transfer(site1, invitee, inviter: initiator)
      t2 = invite_transfer(site2, invitee, inviter: initiator)

      results = Invitations.pending_site_transfers_for(invitee)

      assert length(results) == 2
      ids = Enum.map(results, & &1.transfer_id)
      assert t1.transfer_id in ids
      assert t2.transfer_id in ids
    end

    test "does not return transfers for other users" do
      initiator = new_user()
      site = new_site(owner: initiator)
      other_user = new_user()

      invite_transfer(site, other_user, inviter: initiator)

      assert Invitations.pending_site_transfers_for(new_user()) == []
    end
  end
end
