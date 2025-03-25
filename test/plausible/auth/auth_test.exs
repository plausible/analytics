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

  describe "create_api_key/3" do
    test "creates a new api key" do
      user = new_user(trial_expiry_date: Date.utc_today())
      key = Ecto.UUID.generate()
      assert {:ok, %Auth.ApiKey{}} = Auth.create_api_key(user, "my new key", key)
    end

    @tag :ee_only
    test "defaults to 600 requests per hour limit in EE" do
      user = new_user(trial_expiry_date: Date.utc_today())

      {:ok, %Auth.ApiKey{hourly_request_limit: hourly_request_limit}} =
        Auth.create_api_key(user, "my new EE key", Ecto.UUID.generate())

      assert hourly_request_limit == 600
    end

    @tag :ce_build_only
    test "defaults to 1000000 requests per hour limit in CE" do
      user = new_user(trial_expiry_date: Date.utc_today())

      {:ok, %Auth.ApiKey{hourly_request_limit: hourly_request_limit}} =
        Auth.create_api_key(user, "my new CE key", Ecto.UUID.generate())

      assert hourly_request_limit == 1_000_000
    end

    test "errors when key already exists" do
      u1 = new_user(trial_expiry_date: Date.utc_today())
      u2 = new_user(trial_expiry_date: Date.utc_today())
      key = Ecto.UUID.generate()
      assert {:ok, %Auth.ApiKey{}} = Auth.create_api_key(u1, "my new key", key)
      assert {:error, changeset} = Auth.create_api_key(u2, "my other key", key)

      assert changeset.errors[:key] ==
               {"has already been taken",
                [constraint: :unique, constraint_name: "api_keys_key_hash_index"]}
    end

    @tag :ee_only
    test "returns error when user is on a growth plan" do
      user = new_user() |> subscribe_to_growth_plan()

      assert {:error, :upgrade_required} =
               Auth.create_api_key(user, "my new key", Ecto.UUID.generate())
    end

    test "creates a key for user on a growth plan when they are an owner of more than one team" do
      user = new_user() |> subscribe_to_growth_plan()
      another_site = new_site()
      add_member(another_site.team, user: user, role: :owner)

      assert {:ok, %Auth.ApiKey{}} =
               Auth.create_api_key(user, "my new key", Ecto.UUID.generate())
    end
  end

  describe "delete_api_key/2" do
    test "deletes the record" do
      user = new_user(trial_expiry_date: Date.utc_today())
      assert {:ok, api_key} = Auth.create_api_key(user, "my new key", Ecto.UUID.generate())
      assert :ok = Auth.delete_api_key(user, api_key.id)
      refute Plausible.Repo.reload(api_key)
    end

    test "returns error when api key does not exist or does not belong to user" do
      me = new_user(trial_expiry_date: Date.utc_today())

      other_user = new_user(trial_expiry_date: Date.utc_today())
      {:ok, other_api_key} = Auth.create_api_key(other_user, "my new key", Ecto.UUID.generate())

      assert {:error, :not_found} = Auth.delete_api_key(me, other_api_key.id)
      assert {:error, :not_found} = Auth.delete_api_key(me, -1)
    end
  end
end
