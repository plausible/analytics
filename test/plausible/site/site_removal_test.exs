defmodule Plausible.Site.SiteRemovalTest do
  use Plausible.DataCase, async: true
  use Oban.Testing, repo: Plausible.Repo
  use Plausible.Teams.Test

  alias Plausible.Site.Removal
  alias Plausible.Sites

  test "site from postgres is immediately deleted" do
    site = new_site()
    assert {:ok, context} = Removal.run(site)
    assert context.delete_all == {1, nil}
    refute Sites.get_by_domain(site.domain)
  end

  test "site deletion prunes team guest memberships" do
    owner = new_user()
    site = new_site(owner: owner)

    team_membership =
      insert(:team_membership, user: build(:user), team: site.team, role: :guest)

    insert(:guest_membership, team_membership: team_membership, site: site, role: :viewer)

    team_invitation =
      insert(:team_invitation,
        email: "sitedeletion@example.test",
        team: site.team,
        inviter: owner,
        role: :guest
      )

    insert(:guest_invitation, team_invitation: team_invitation, site: site, role: :viewer)

    assert {:ok, context} = Removal.run(site)
    assert context.delete_all == {1, nil}

    refute Repo.reload(team_membership)
    refute Repo.reload(team_invitation)
  end

  test "site deletion updates team dashboard lock state" do
    owner = new_user(team: [locked: true])
    site = new_site(owner: owner)
    team = site.team

    assert team.locked

    assert {:ok, context} = Removal.run(site)
    assert context.delete_all == {1, nil}
    refute Sites.get_by_domain(site.domain)

    refute Repo.reload(team).locked
  end
end
