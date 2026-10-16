defmodule Plausible.Teams.Management.RosterTest do
  use Plausible.DataCase, async: true

  alias Plausible.Teams.Management.Roster
  alias Plausible.Teams.Management.Roster.Entry
  alias Plausible.Teams

  describe "init/1" do
    setup [:create_user, :create_team]

    test "loads the team's members and pending invitations", %{user: owner, team: team} do
      viewer = add_member(team, role: :viewer)
      invite_member(team, "invitee@example.com", role: :editor, inviter: owner)

      roster = Roster.init(team)

      assert %Entry{role: :owner, source: %Teams.Membership{}} = roster[owner.email]
      assert %Entry{role: :viewer, source: %Teams.Membership{}} = roster[viewer.email]

      assert %Entry{name: "Invited User", role: :editor, source: %Teams.Invitation{}} =
               roster["invitee@example.com"]

      assert map_size(roster) == 3
    end
  end

  test "can be built of invitations and memberships" do
    roster = sample_roster()

    assert %Entry{name: "Current User", role: :admin, source: %Teams.Membership{user: %{id: 777}}} =
             roster["current@example.com"]

    assert %Entry{name: "Owner User", role: :owner, source: %Teams.Membership{}} =
             roster["owner@example.com"]

    assert %Entry{name: "Invited User", role: :admin, source: %Teams.Invitation{}} =
             roster["invitation-sent@example.com"]
  end

  test "can be sorted for display" do
    assert [
             {"invitation-sent@example.com", %Entry{source: %Teams.Invitation{}}},
             {"current@example.com", %Entry{source: %Teams.Membership{}}},
             {"owner@example.com", %Entry{source: %Teams.Membership{}}},
             {"invitation-sent-guest@example.com",
              %Entry{role: :guest, source: %Teams.Invitation{}}},
             {"a-guest@example.com", %Entry{role: :guest, source: %Teams.Membership{}}}
           ] = Roster.sorted_for_display(sample_roster())

    roster =
      sample_roster()
      |> put(membership(name: "Aa", email: "00-invitation-accepted@example.com", role: :viewer))
      |> put(invitation_sent("00-invitation-sent@example.com"))

    assert [
             {"00-invitation-sent@example.com", %Entry{}},
             {"invitation-sent@example.com", %Entry{}},
             {"00-invitation-accepted@example.com", %Entry{}},
             {"current@example.com", %Entry{}},
             {"owner@example.com", %Entry{}},
             {"invitation-sent-guest@example.com",
              %Entry{role: :guest, source: %Teams.Invitation{}}},
             {"a-guest@example.com", %Entry{role: :guest, source: %Teams.Membership{}}}
           ] = Roster.sorted_for_display(roster)
  end

  test "removable?/2 + owners_count/1" do
    roster = sample_roster()
    assert Roster.removable?(roster, "invitation-sent@example.com")
    assert Roster.removable?(roster, "current@example.com")
    refute Roster.removable?(roster, "owner@example.com")

    # A pending owner invitation doesn't count as another owner yet
    roster = put(roster, invitation_sent("maybe-owner@example.com", role: :owner))

    refute Roster.removable?(roster, "owner@example.com")

    roster = put(roster, membership(email: "secondary-owner@example.com", role: :owner))

    assert Roster.removable?(roster, "owner@example.com")
    assert Roster.removable?(roster, "secondary-owner@example.com")

    assert Roster.owners_count(roster) == 3
  end

  test "users/1 returns the users of memberships, leaving out invitations" do
    current_user = build(:user, name: "Member", email: "member@example.com")

    roster =
      Roster.build_by_email([
        membership(role: :viewer, user: current_user),
        invitation_sent("invitee@example.com")
      ])

    assert [%{email: "member@example.com"}] = Roster.users(roster)
  end

  test "has_guests?/1" do
    roster = Roster.build_by_email([invitation_sent("invitation-sent@example.com")])
    refute Roster.has_guests?(roster)

    assert roster
           |> put(membership(email: "guest@example.com", role: :guest))
           |> Roster.has_guests?()

    assert roster
           |> put(invitation_sent("guest-invitation@example.com", role: :guest))
           |> Roster.has_guests?()
  end

  test "a membership takes precedence over an invitation for the same e-mail" do
    roster =
      Roster.build_by_email([
        invitation_sent("same@example.com", role: :admin),
        membership(email: "same@example.com", role: :viewer)
      ])

    assert %{"same@example.com" => %Entry{source: %Teams.Membership{}, role: :viewer}} = roster
  end

  test "Entry.invitation?/1 tells invitations and memberships apart" do
    assert Entry.invitation?(Entry.new(invitation_sent("invitee@example.com")))
    refute Entry.invitation?(Entry.new(membership(email: "member@example.com", role: :viewer)))
  end

  defp put(roster, entity) do
    entry = Entry.new(entity)
    Map.put(roster, entry.email, entry)
  end

  defp invitation_sent(email, attrs \\ []) do
    build(
      :team_invitation,
      Keyword.merge([email: email, id: Enum.random(1..1_000_000)], attrs)
    )
  end

  defp membership(attrs) do
    build(:team_membership,
      role: attrs[:role],
      user: attrs[:user] || build(:user, name: attrs[:name], email: attrs[:email])
    )
  end

  defp sample_roster() do
    current_user = build(:user, id: 777, name: "Current User", email: "current@example.com")

    Roster.build_by_email([
      membership(role: :owner, name: "Owner User", email: "owner@example.com"),
      membership(role: :guest, name: "Guest User", email: "a-guest@example.com"),
      membership(role: :admin, user: current_user),
      invitation_sent("invitation-sent-guest@example.com", role: :guest),
      invitation_sent("invitation-sent@example.com")
    ])
  end
end
