defmodule Plausible.ReleaseTest do
  use Plausible.DataCase
  alias Plausible.{Release, Auth}

  setup do
    prev_env = Application.get_all_env(:plausible)
    on_exit(fn -> Application.put_all_env(plausible: prev_env) end)
  end

  test "first_launch? is set on app startup" do
    # and due to env vars in test env, it's false
    assert Release.first_launch?() == false
  end

  describe "should_be_first_launch?/0" do
    test "returns true when self-hosted and no users" do
      :ok = Application.put_env(:plausible, :is_selfhost, true)
      false = Repo.exists?(Auth.User)
      assert Release.should_be_first_launch?()
    end

    test "returns false when not self-hosted or has users" do
      # not selfhost, no users
      false = Application.fetch_env!(:plausible, :is_selfhost)
      false = Repo.exists?(Auth.User)
      refute Release.should_be_first_launch?()

      # not selfhost, has users
      insert(:user)
      refute Release.should_be_first_launch?()

      # selfhost, has users
      :ok = Application.put_env(:plausible, :is_selfhost, true)
      refute Release.should_be_first_launch?()
    end
  end

  describe "set_first_launch/1 and first_launch?/0" do
    setup do
      :ok = Application.delete_env(:plausible, :first_launch?)
    end

    test "defaults to should_be_first_launch?/0" do
      false = Release.should_be_first_launch?()
      :ok = Release.set_first_launch()
      assert Release.first_launch?() == false

      :ok = Application.put_env(:plausible, :is_selfhost, true)

      true = Release.should_be_first_launch?()
      :ok = Release.set_first_launch()
      assert Release.first_launch?() == true
    end
  end
end
