defmodule Plausible.AuthTest do
  use Plausible.DataCase, async: true
  use Plausible.Teams.Test
  alias Plausible.Auth

  describe "user_completed_setup?" do
    test "is false if user does not have any sites" do
      user = insert(:user)

      refute Auth.has_active_sites?(user)
    end

    test "is false if user does not have any events" do
      user = insert(:user)
      insert(:site, members: [user])

      refute Auth.has_active_sites?(user)
    end

    test "is true if user does have events" do
      user = insert(:user)
      site = insert(:site, members: [user])

      populate_stats(site, [
        build(:pageview)
      ])

      assert Auth.has_active_sites?(user)
    end

    test "can specify which roles we're looking for" do
      user = insert(:user)

      insert(:site,
        domain: "test-site.com",
        memberships: [
          build(:site_membership, user: user, role: :admin)
        ]
      )

      refute Auth.has_active_sites?(user, [:owner])
    end
  end

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
      user = new_user()
      key = Ecto.UUID.generate()
      assert {:ok, %Auth.ApiKey{}} = Auth.create_api_key(user, "my new key", key)
    end

    @tag :ee_only
    test "defaults to 600 requests per hour limit in EE" do
      user = new_user()

      {:ok, %Auth.ApiKey{hourly_request_limit: hourly_request_limit}} =
        Auth.create_api_key(user, "my new EE key", Ecto.UUID.generate())

      assert hourly_request_limit == 600
    end

    @tag :ce_build_only
    test "defaults to 1000000 requests per hour limit in CE" do
      user = new_user()

      {:ok, %Auth.ApiKey{hourly_request_limit: hourly_request_limit}} =
        Auth.create_api_key(user, "my new CE key", Ecto.UUID.generate())

      assert hourly_request_limit == 1_000_000
    end

    test "errors when key already exists" do
      u1 = new_user()
      u2 = new_user()
      key = Ecto.UUID.generate()
      assert {:ok, %Auth.ApiKey{}} = Auth.create_api_key(u1, "my new key", key)
      assert {:error, changeset} = Auth.create_api_key(u2, "my other key", key)

      assert changeset.errors[:key] ==
               {"has already been taken",
                [constraint: :unique, constraint_name: "api_keys_key_hash_index"]}
    end

    @tag :ee_only
    test "returns error when user is on a growth plan" do
      user = insert(:user, subscription: build(:growth_subscription))

      assert {:error, :upgrade_required} =
               Auth.create_api_key(user, "my new key", Ecto.UUID.generate())
    end
  end

  describe "delete_api_key/2" do
    test "deletes the record" do
      user = new_user()
      assert {:ok, api_key} = Auth.create_api_key(user, "my new key", Ecto.UUID.generate())
      assert :ok = Auth.delete_api_key(user, api_key.id)
      refute Plausible.Repo.reload(api_key)
    end

    test "returns error when api key does not exist or does not belong to user" do
      me = new_user()

      other_user = new_user()
      {:ok, other_api_key} = Auth.create_api_key(other_user, "my new key", Ecto.UUID.generate())

      assert {:error, :not_found} = Auth.delete_api_key(me, other_api_key.id)
      assert {:error, :not_found} = Auth.delete_api_key(me, -1)
    end
  end
end
