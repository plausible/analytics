defmodule PlausibleWeb.FirstLaunchPlugTest do
  use PlausibleWeb.ConnCase
  @moduletag :ce_build_only
  import Plug.Test

  alias PlausibleWeb.FirstLaunchPlug
  alias Plausible.Release

  describe "init/1" do
    test "requires :redirect_to option" do
      assert_raise KeyError, ~r"key :redirect_to not found", fn ->
        FirstLaunchPlug.init(_no_opts = [])
      end

      path = FirstLaunchPlug.init(redirect_to: "/register")
      assert path == "/register"
    end
  end

  @opts FirstLaunchPlug.init(redirect_to: "/register")

  describe "call/2" do
    test "no-op for paths == :redirect_to" do
      conn = conn("GET", "/register")
      conn = FirstLaunchPlug.call(conn, @opts)
      refute conn.halted

      # even when it's the first launch
      assert Release.should_be_first_launch?()

      conn = conn("GET", "/register")
      conn = FirstLaunchPlug.call(conn, @opts)
      refute conn.halted
    end

    test "no-op when not first launch" do
      insert(:user)
      refute Release.should_be_first_launch?()
      conn = conn("GET", "/sites")
      conn = FirstLaunchPlug.call(conn, @opts)
      refute conn.halted
    end

    test "redirects to :redirect_to when first launch" do
      assert Release.should_be_first_launch?()

      conn = conn("GET", "/sites")
      conn = FirstLaunchPlug.call(conn, @opts)
      assert conn.halted
      assert redirected_to(conn) == "/register"
    end
  end

  describe "first launch plug in :browser pipeline" do
    test "redirects to /register on first launch", %{conn: conn} do
      assert Release.should_be_first_launch?()

      conn = get(conn, "/")
      assert redirected_to(conn) == "/register"
    end
  end
end
