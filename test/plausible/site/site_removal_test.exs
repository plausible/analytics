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

  @tag :skip
  @tag :teams
  test "site deletion prunes team guest memberships" do
    site = insert(:site) |> Plausible.Teams.load_for_site() |> Repo.preload(:owner)

    team_membership =
      insert(:team_membership, user: build(:user), team: site.team, role: :guest)

    insert(:guest_membership, team_membership: team_membership, site: site, role: :viewer)

    team_invitation =
      insert(:team_invitation,
        email: "sitedeletion@example.test",
        team: site.team,
        inviter: site.owner,
        role: :guest
      )

    insert(:guest_invitation, team_invitation: team_invitation, site: site, role: :viewer)

    assert {:ok, context} = Removal.run(site)
    assert context.delete_all == {1, nil}

    refute Repo.reload(team_membership)
    refute Repo.reload(team_invitation)
  end
end
