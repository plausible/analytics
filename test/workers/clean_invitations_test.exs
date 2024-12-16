defmodule Plausible.Workers.CleanInvitationsTest do
  use Plausible.DataCase
  use Plausible.Teams.Test
  alias Plausible.Workers.CleanInvitations

  test "cleans invitations and transfers that are more than 48h old" do
    now = NaiveDateTime.utc_now(:second)

    owner = new_user()
    site = new_site(owner: owner)

    invite_guest(site, new_user(),
      role: :viewer,
      inviter: owner,
      inserted_at: NaiveDateTime.shift(now, hour: -49),
      team_invitation: [inserted_at: NaiveDateTime.shift(now, hour: -49)]
    )

    invite_transfer(site, new_user(),
      inviter: owner,
      inserted_at: NaiveDateTime.shift(now, hour: -49)
    )

    CleanInvitations.perform(nil)

    refute Repo.exists?(Plausible.Teams.Invitation)
    refute Repo.exists?(Plausible.Teams.GuestInvitation)
    refute Repo.exists?(Plausible.Teams.SiteTransfer)
  end

  test "does not clean invitations and transfers that are less than 48h old" do
    now = NaiveDateTime.utc_now(:second)

    owner = new_user()
    site = new_site(owner: owner)

    invite_guest(site, new_user(),
      role: :viewer,
      inviter: owner,
      inserted_at: NaiveDateTime.shift(now, hour: -47),
      team_invitation: [inserted_at: NaiveDateTime.shift(now, hour: -47)]
    )

    invite_transfer(site, new_user(),
      inviter: owner,
      inserted_at: NaiveDateTime.shift(now, hour: -47)
    )

    CleanInvitations.perform(nil)

    assert Repo.exists?(Plausible.Teams.Invitation)
    assert Repo.exists?(Plausible.Teams.GuestInvitation)
    assert Repo.exists?(Plausible.Teams.SiteTransfer)
  end
end
