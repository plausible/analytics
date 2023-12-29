defmodule Plausible.UsersTest do
  use Plausible.DataCase, async: true

  alias Plausible.Users
  alias Plausible.Auth.User
  alias Plausible.Repo

  describe "update_accept_traffic_until" do
    @describetag :full_build_only
    test "update" do
      user = insert(:user) |> User.start_trial() |> Repo.update!()
      # 30 for trial + 14
      assert Date.diff(user.accept_traffic_until, Date.utc_today()) ==
               30 + User.trial_accept_traffic_until_offset_days()

      future = Date.add(Date.utc_today(), 30)
      insert(:subscription, user: user, next_bill_date: future)

      assert updated_user = Users.update_accept_traffic_until(user)

      assert Date.diff(updated_user.accept_traffic_until, future) ==
               User.subscription_accept_traffic_until_offset_days()
    end

    test "retrieve: trial + 14 days" do
      user = insert(:user)

      assert Users.accept_traffic_until(user) ==
               Date.utc_today() |> Date.add(30 + User.trial_accept_traffic_until_offset_days())
    end

    test "retrieve: last_bill_date + 30 days" do
      future = Date.add(Date.utc_today(), 30)
      user = insert(:user, subscription: build(:subscription, next_bill_date: future))

      assert Users.accept_traffic_until(user) ==
               future |> Date.add(User.subscription_accept_traffic_until_offset_days())
    end

    test "retrieve: free plan" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: "free_10k"))

      assert Users.accept_traffic_until(user) == ~D[2135-01-01]
    end

    test "retrieve: invalid user (there's one in the prod DB as of today, due to some testing)" do
      user = insert(:user, trial_expiry_date: nil)

      assert_raise RuntimeError,
                   ~r/Manual intervention required/,
                   fn ->
                     assert Users.accept_traffic_until(user) == ~D[2135-01-01]
                   end
    end
  end
end
