defmodule Plausible.Site.DomainTest do
  alias Plausible.Site
  alias Plausible.Site.Domain

  use Plausible.DataCase, async: true

  test "successful change" do
    site = insert(:site)
    assert {:ok, updated} = Domain.change(site, "new-domain.example.com")
    assert updated.domain_changed_from == site.domain
    assert updated.domain == "new-domain.example.com"
    assert updated.domain_changed_at
  end

  test "domain_changed_from is kept unique, so no double change is possible" do
    site1 = insert(:site)
    assert {:ok, _} = Domain.change(site1, "new-domain.example.com")

    site2 = insert(:site)
    assert {:error, changeset} = Domain.change(site2, "new-domain.example.com")
    assert {error_message, _} = changeset.errors[:domain]
    assert error_message =~ "This domain cannot be registered"
  end

  test "domain is also guaranteed unique against existing domain_changed_from entries" do
    site1 =
      insert(:site, domain: "site1.example.com", domain_changed_from: "oldsite1.example.com")

    site2 = insert(:site, domain: "site2.example.com")

    assert {:error, %{errors: [{:domain, {error, _}}]}} = Domain.change(site2, site1.domain)

    assert {:error, %{errors: [{:domain, {^error, _}}]}} =
             Domain.change(site2, site1.domain_changed_from)

    assert error =~ "This domain cannot be registered"
  end

  test "a single site's domain can be changed back and forth" do
    site1 = insert(:site, domain: "foo.example.com")
    site2 = insert(:site, domain: "baz.example.com")

    assert {:ok, _} = Domain.change(site1, "bar.example.com")

    assert {:error, _} = Domain.change(site2, "bar.example.com")
    assert {:error, _} = Domain.change(site2, "foo.example.com")

    assert {:ok, _} = Domain.change(Repo.reload!(site1), "foo.example.com")
    assert {:ok, _} = Domain.change(Repo.reload!(site1), "bar.example.com")
  end

  test "domain swap is allowed between sites in the same team" do
    team = insert(:team)
    site1 = insert(:site, domain: "one.example.com", team: team)
    site2 = insert(:site, domain: "two.example.com", team: team)

    assert {:ok, _} = Domain.change(site1, "tmp-one.example.com")

    # site1's old domain "one.example.com" is now in domain_changed_from,
    # but site2 is on the same team so swapping is allowed
    assert {:ok, updated} = Domain.change(Repo.reload!(site2), "one.example.com")
    assert updated.domain == "one.example.com"
  end

  test "domain swap is blocked between sites in different teams" do
    team1 = insert(:team)
    team2 = insert(:team)
    site1 = insert(:site, domain: "one.example.com", team: team1)
    site2 = insert(:site, domain: "two.example.com", team: team2)

    assert {:ok, _} = Domain.change(site1, "tmp-one.example.com")

    assert {:error, changeset} = Domain.change(Repo.reload!(site2), "one.example.com")
    assert {error_message, _} = changeset.errors[:domain]
    assert error_message =~ "This domain cannot be registered"
  end

  test "change info is cleared when the grace period expires" do
    site = insert(:site)

    assert {:ok, site} = Domain.change(site, "new-domain.example.com")
    assert site.domain_changed_from
    assert site.domain_changed_at

    assert {:ok, _} = Domain.expire_change_transitions(-1)
    expired_site = Repo.reload!(site)
    refute expired_site.domain_changed_from
    assert expired_site.domain_changed_at
  end

  test "expire changes overdue" do
    now = NaiveDateTime.utc_now()
    yesterday = now |> NaiveDateTime.add(-60 * 60 * 24, :second)
    three_days_ago = now |> NaiveDateTime.add(-60 * 60 * 72, :second)

    {:ok, s1} = insert(:site) |> Domain.change("new-domain1.example.com")
    {:ok, s2} = insert(:site) |> Domain.change("new-domain2.example.com", at: yesterday)

    {:ok, s3} = insert(:site) |> Domain.change("new-domain3.example.com", at: three_days_ago)

    assert {:ok, 1} = Domain.expire_change_transitions()

    s3_after = Repo.reload!(s3)
    assert is_nil(s3_after.domain_changed_from)
    assert s3_after.domain_changed_at

    assert {:ok, 1} = Domain.expire_change_transitions(24)
    s2_after = Repo.reload!(s2)
    assert is_nil(s2_after.domain_changed_from)
    assert s2_after.domain_changed_at

    assert {:ok, 0} = Domain.expire_change_transitions()
    s1_after = Repo.reload!(s1)
    assert s1_after.domain_changed_from
    assert s1_after.domain_changed_at
  end

  test "new domain gets validated" do
    site = build(:site)
    changeset = Site.update_changeset(site, %{domain: " "})
    assert {"can't be blank", _} = changeset.errors[:domain]

    changeset = Site.update_changeset(site, %{domain: "?#[]"})
    assert {"must not contain URI reserved characters" <> _, _} = changeset.errors[:domain]
  end
end
