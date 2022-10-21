defmodule PlausibleWeb.FirstLaunchPlugTest do
  use PlausibleWeb.ConnCase
  import Plug.Test

  alias PlausibleWeb.FirstLaunchPlug
  alias Plausible.Release

  setup do
    prev_env = Application.get_all_env(:plausible)
    on_exit(fn -> Application.put_all_env(plausible: prev_env) end)
  end

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
      :ok = Application.put_env(:plausible, :is_selfhost, true)
      true = Release.should_be_first_launch?()
      :ok = Release.set_first_launch()

      conn = conn("GET", "/register")
      conn = FirstLaunchPlug.call(conn, @opts)
      refute conn.halted
    end

    test "no-op when not first launch" do
      false = Release.first_launch?()
      conn = conn("GET", "/sites")
      conn = FirstLaunchPlug.call(conn, @opts)
      refute conn.halted
    end

    test "redirects to :redirect_to when first launch" do
      :ok = Application.put_env(:plausible, :is_selfhost, true)
      true = Release.should_be_first_launch?()
      :ok = Release.set_first_launch()

      conn = conn("GET", "/sites")
      conn = FirstLaunchPlug.call(conn, @opts)
      assert conn.halted
      assert redirected_to(conn) == "/register"
    end

    test "re-checks and resets first_launch?" do
      false = Release.should_be_first_launch?()
      # but
      :ok = Release.set_first_launch(true)

      # no-op ...
      conn = conn("GET", "/")
      conn = FirstLaunchPlug.call(conn, @opts)
      refute conn.halted

      # ... and
      assert Release.first_launch?() == false
    end
  end

  describe "first launch plug in :browser pipeline" do
    test "redirects to /register on first launch", %{conn: conn} do
      :ok = Application.put_env(:plausible, :is_selfhost, true)
      true = Release.should_be_first_launch?()
      :ok = Release.set_first_launch()

      conn = get(conn, "/")
      assert redirected_to(conn) == "/register"
    end

    test "no-op when not first launch", %{conn: conn} do
      false = Release.first_launch?()

      # gets redirected to login by auth plugs
      # "first launch" doesn't interfere
      conn = get(conn, "/sites")
      assert redirected_to(conn) == "/login"
    end
  end
end
