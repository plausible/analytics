defmodule Plausible.Workers.CleanInvitationsTest do
  use Plausible.DataCase
  alias Plausible.Workers.CleanInvitations

  test "cleans invitations and transfers that are more than 48h old" do
    now = NaiveDateTime.utc_now(:second)

    insert(:invitation,
      inserted_at: NaiveDateTime.shift(now, hour: -49),
      site: build(:site),
      inviter: build(:user)
    )

    site = insert(:site, team: build(:team))

    team_invitation =
      insert(:team_invitation,
        inserted_at: NaiveDateTime.shift(now, hour: -49),
        team: site.team,
        inviter: build(:user),
        role: :guest
      )

    insert(:guest_invitation,
      inserted_at: NaiveDateTime.shift(now, hour: -49),
      team_invitation: team_invitation,
      site: site,
      role: :viewer
    )

    insert(:site_transfer,
      inserted_at: NaiveDateTime.shift(now, hour: -49),
      site: site,
      initiator: build(:user)
    )

    CleanInvitations.perform(nil)

    refute Repo.exists?(Plausible.Auth.Invitation)
    refute Repo.exists?(Plausible.Teams.Invitation)
    refute Repo.exists?(Plausible.Teams.GuestInvitation)
    refute Repo.exists?(Plausible.Teams.SiteTransfer)
  end

  test "does not clean invitations and transfers that are less than 48h old" do
    now = NaiveDateTime.utc_now(:second)

    insert(:invitation,
      inserted_at: NaiveDateTime.shift(now, hour: -47),
      site: build(:site),
      inviter: build(:user)
    )

    site = insert(:site, team: build(:team))

    team_invitation =
      insert(:team_invitation,
        inserted_at: NaiveDateTime.shift(now, hour: -47),
        team: site.team,
        inviter: build(:user),
        role: :guest
      )

    insert(:guest_invitation,
      inserted_at: NaiveDateTime.shift(now, hour: -47),
      team_invitation: team_invitation,
      site: site,
      role: :viewer
    )

    insert(:site_transfer,
      inserted_at: NaiveDateTime.shift(now, hour: -47),
      site: site,
      initiator: build(:user)
    )

    CleanInvitations.perform(nil)

    assert Repo.exists?(Plausible.Auth.Invitation)
  end
end
