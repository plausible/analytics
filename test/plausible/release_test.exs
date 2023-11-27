defmodule Plausible.ReleaseTest do
  use Plausible.DataCase
  alias Plausible.{Release, Auth}
  import ExUnit.CaptureIO

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

  test "dump_plans/0 inserts plans" do
    stdout =
      capture_io(fn ->
        Release.dump_plans()
      end)

    assert stdout =~ "Loading plausible.."
    assert stdout =~ "Starting dependencies.."
    assert stdout =~ "Starting repos.."
    assert stdout =~ "Inserted 54 plans"
  end
end
