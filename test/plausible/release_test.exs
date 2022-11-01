defmodule Plausible.ReleaseTest do
  use Plausible.DataCase
  alias Plausible.{Release, Auth}

  describe "should_be_first_launch?/0" do
    test "returns true when self-hosted and no users" do
      patch_env(:is_selfhost, true)
      refute Repo.exists?(Auth.User)
      assert Release.should_be_first_launch?()
    end

    test "returns false when not self-hosted and has no users" do
      patch_env(:is_selfhost, false)
      refute Repo.exists?(Auth.User)
      refute Release.should_be_first_launch?()
    end

    test "returns false when not self-hosted and has users" do
      insert(:user)
      patch_env(:is_selfhost, false)
      refute Release.should_be_first_launch?()
    end

    test "returns false when self-hosted and has users" do
      insert(:user)
      patch_env(:is_selfhost, true)
      refute Release.should_be_first_launch?()
    end
  end
end
