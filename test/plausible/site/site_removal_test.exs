defmodule Plausible.Site.SiteRemovalTest do
  use Plausible.DataCase, async: true
  use Oban.Testing, repo: Plausible.Repo

  alias Plausible.PendingStatsDeletion
  alias Plausible.Site.Removal
  alias Plausible.Sites

  test "site from postgres is immediately deleted" do
    site = new_site()
    assert {:ok, context} = Removal.run(site)
    assert context.delete_all == {1, nil}
    refute Sites.get_by_domain(site.domain)
  end

  test "site deletion stores a pending stats deletion record" do
    site = new_site()

    populate_stats(site, [
      build(:pageview, timestamp: ~N[2020-01-01 12:00:00]),
      build(:pageview, timestamp: ~N[2020-01-10 12:00:00])
    ])

    assert {:ok, context} = Removal.run(site)

    assert %PendingStatsDeletion{} = pending_deletion = context.pending_stats_deletion
    assert pending_deletion.site_id == site.id
    assert pending_deletion.reason == :user_request

    assert Repo.get_by(PendingStatsDeletion, site_id: site.id)
  end

  test "site deletion stores a pending stats deletion record even if the site has no stats" do
    site = new_site()

    assert {:ok, context} = Removal.run(site)

    assert %PendingStatsDeletion{site_id: site_id} = context.pending_stats_deletion
    assert site_id == site.id
    assert Repo.get_by(PendingStatsDeletion, site_id: site.id)
  end

  test "site deletion accepts an explicit reason for the pending stats deletion" do
    site = new_site()

    assert {:ok, context} = Removal.run(site, reason: :expired_trial)

    assert context.pending_stats_deletion.reason == :expired_trial
    assert Repo.get_by(PendingStatsDeletion, site_id: site.id, reason: :expired_trial)
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

  on_ee do
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

    test "site deletion disables consolidated view if need be" do
      owner = new_user()
      site = new_site(owner: owner)
      new_site(owner: owner)
      team = team_of(owner)

      new_consolidated_view(team)
      assert Plausible.ConsolidatedView.get(team)

      assert {:ok, _} = Removal.run(site)

      refute Plausible.ConsolidatedView.get(team)
    end

    test "site deletion keeps consolidated view if there's still regular sites" do
      owner = new_user()
      site = new_site(owner: owner)

      # another site
      new_site(owner: owner)
      # third site to ensure we still have 2+ after deletion
      new_site(owner: owner)

      team = team_of(owner)

      new_consolidated_view(team)
      assert Plausible.ConsolidatedView.get(team)

      assert {:ok, _} = Removal.run(site)

      assert Plausible.ConsolidatedView.get(team)
    end
  end

  test "site is removed from sites cache upon deletion", %{test: test} do
    {:ok, _} = start_test_cache(test)
    site = new_site(domain_changed_from: "#{test}")

    Plausible.Site.Cache.refresh_all(cache_name: test)

    assert Plausible.Site.Cache.get(site.domain, cache_name: test, force?: true)
    assert Plausible.Site.Cache.get(site.domain_changed_from, cache_name: test, force?: true)

    assert {:ok, _} = Removal.run(site, cache_name: test)

    refute Plausible.Site.Cache.get(site.domain, cache_name: test, force?: true)
    refute Plausible.Site.Cache.get(site.domain_changed_from, cache_name: test, force?: true)
  end

  defp start_test_cache(cache_name) do
    %{start: {m, f, a}} = Plausible.Site.Cache.child_spec(cache_name: cache_name)
    apply(m, f, a)
  end
end
