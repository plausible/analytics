defmodule Plausible.AuthTest do
  use Plausible.DataCase, async: true
  use Plausible.Teams.Test
  alias Plausible.Auth

  test "enterprise_configured?/1 returns whether the user has an enterprise plan" do
    user_without_plan = new_user()
    user_with_plan = new_user() |> subscribe_to_enterprise_plan()

    user_with_plan_no_subscription =
      new_user() |> subscribe_to_enterprise_plan(subscription?: false)

    assert Plausible.Teams.Billing.enterprise_configured?(team_of(user_with_plan))

    assert Plausible.Teams.Billing.enterprise_configured?(team_of(user_with_plan_no_subscription))

    refute Plausible.Teams.Billing.enterprise_configured?(team_of(user_without_plan))
    refute Plausible.Teams.Billing.enterprise_configured?(nil)
  end

  describe "create_stats_api_key/3" do
    test "creates a new api key" do
      user = new_user(trial_expiry_date: Date.utc_today())
      team = team_of(user)
      key = Ecto.UUID.generate()

      assert {:ok, %Auth.ApiKey{} = api_key} =
               Auth.create_stats_api_key(user, team, "my new key", key)

      assert api_key.team_id == team.id
      assert api_key.user_id == user.id
    end

    test "errors when key already exists" do
      u1 = new_user(trial_expiry_date: Date.utc_today())
      t1 = team_of(u1)
      u2 = new_user(trial_expiry_date: Date.utc_today())
      t2 = team_of(u2)
      key = Ecto.UUID.generate()
      assert {:ok, %Auth.ApiKey{}} = Auth.create_stats_api_key(u1, t1, "my new key", key)
      assert {:error, changeset} = Auth.create_stats_api_key(u2, t2, "my other key", key)

      assert changeset.errors[:key] ==
               {"has already been taken",
                [constraint: :unique, constraint_name: "api_keys_key_hash_index"]}
    end

    @tag :ee_only
    test "returns error when team is on a growth plan" do
      user = new_user() |> subscribe_to_growth_plan()
      team = team_of(user)

      assert {:error, :upgrade_required} =
               Auth.create_stats_api_key(user, team, "my new key", Ecto.UUID.generate())
    end

    test "creates a key for user in a team with a bunsiness plan" do
      user = new_user() |> subscribe_to_business_plan()
      team = team_of(user)
      another_site = new_site()
      add_member(another_site.team, user: user, role: :owner)

      assert {:ok, %Auth.ApiKey{}} =
               Auth.create_stats_api_key(user, team, "my new key", Ecto.UUID.generate())
    end
  end

  describe "create_sites_api_key/3" do
    test "creates a new api key for user on enterprise plan with SitesAPI enabled" do
      user =
        new_user()
        |> subscribe_to_enterprise_plan(
          features: [Plausible.Billing.Feature.StatsAPI, Plausible.Billing.Feature.SitesAPI]
        )

      team = team_of(user)
      key = Ecto.UUID.generate()

      assert {:ok, %Auth.ApiKey{} = api_key} =
               Auth.create_sites_api_key(user, team, "my new key", key)

      assert api_key.team_id == team.id
      assert api_key.user_id == user.id
    end

    test "errors when key already exists" do
      u1 =
        new_user()
        |> subscribe_to_enterprise_plan(
          features: [Plausible.Billing.Feature.StatsAPI, Plausible.Billing.Feature.SitesAPI]
        )

      t1 = team_of(u1)

      u2 =
        new_user()
        |> subscribe_to_enterprise_plan(
          features: [Plausible.Billing.Feature.StatsAPI, Plausible.Billing.Feature.SitesAPI]
        )

      t2 = team_of(u2)
      key = Ecto.UUID.generate()
      assert {:ok, %Auth.ApiKey{}} = Auth.create_sites_api_key(u1, t1, "my new key", key)
      assert {:error, changeset} = Auth.create_sites_api_key(u2, t2, "my other key", key)

      assert changeset.errors[:key] ==
               {"has already been taken",
                [constraint: :unique, constraint_name: "api_keys_key_hash_index"]}
    end

    @tag :ee_only
    test "returns error when team is on a business plan" do
      user = new_user() |> subscribe_to_business_plan()
      team = team_of(user)

      assert {:error, :upgrade_required} =
               Auth.create_sites_api_key(user, team, "my new key", Ecto.UUID.generate())
    end
  end

  describe "delete_api_key/2" do
    test "deletes the record" do
      user = new_user(trial_expiry_date: Date.utc_today())
      team = team_of(user)

      assert {:ok, api_key} =
               Auth.create_stats_api_key(user, team, "my new key", Ecto.UUID.generate())

      assert :ok = Auth.delete_api_key(user, api_key.id)
      refute Plausible.Repo.reload(api_key)
    end

    test "returns error when api key does not exist or does not belong to user" do
      me = new_user(trial_expiry_date: Date.utc_today())

      other_user = new_user(trial_expiry_date: Date.utc_today())
      other_team = team_of(other_user)

      {:ok, other_api_key} =
        Auth.create_stats_api_key(other_user, other_team, "my new key", Ecto.UUID.generate())

      assert {:error, :not_found} = Auth.delete_api_key(me, other_api_key.id)
      assert {:error, :not_found} = Auth.delete_api_key(me, -1)
    end
  end
end
