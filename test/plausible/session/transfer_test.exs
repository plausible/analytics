defmodule Plausible.Session.TransferTest do
  use ExUnit.Case

  @tag :slow
  test "it works" do
    tmp_dir = tmp_dir()

    old = start_another_plausible(tmp_dir)
    session = put_session(old, %{user_id: 123})

    new = start_another_plausible(tmp_dir)
    await_transfer(new)

    assert get_session(new, {session.site_id, session.user_id}) == session
  end

  # normal `@tag :tmp_dir` might not work if the path is too long for unix domain sockets (>104)
  # this one makes paths a bit shorter like "/tmp/plausible_psp_123/"
  defp tmp_dir do
    tmp_dir = Path.join(System.tmp_dir!(), "plausible_sess_#{System.unique_integer([:positive])}")
    if File.exists?(tmp_dir), do: File.rm_rf!(tmp_dir)
    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    tmp_dir
  end

  defp start_another_plausible(tmp_dir) do
    {:ok, pid, _node} = :peer.start_link(%{connection: {{127, 0, 0, 1}, 0}})
    add_code_paths(pid)
    transfer_configuration(pid)
    :ok = :peer.call(pid, Application, :put_env, [:plausible, :session_transfer_dir, tmp_dir])
    ensure_applications_started(pid)
    pid
  end

  defp add_code_paths(pid) do
    :ok = :peer.call(pid, :code, :add_paths, [:code.get_path()])
  end

  defp transfer_configuration(pid) do
    for {app_name, _, _} <- Application.loaded_applications() do
      for {key, val} <- Application.get_all_env(app_name) do
        :ok = :peer.call(pid, Application, :put_env, [app_name, key, val])
      end
    end
  end

  defp ensure_applications_started(pid) do
    {:ok, _apps} = :peer.call(pid, Application, :ensure_all_started, [:mix])
    :ok = :peer.call(pid, Mix, :env, [Mix.env()])

    for {app_name, _, _} <- Application.loaded_applications(), app_name != :dialyxir do
      {:ok, _apps} = :peer.call(pid, Application, :ensure_all_started, [app_name])
    end
  end

  defp put_session(pid, overrides) do
    user_id = overrides[:user_id] || Enum.random(1000..2000)
    session_id = user_id * 1000 + Enum.random(0..1000)

    default = %Plausible.ClickhouseSessionV2{
      sign: 1,
      session_id: session_id,
      user_id: user_id,
      hostname: "example.com",
      site_id: Enum.random(1000..10_000),
      entry_page: "/",
      pageviews: 1,
      events: 1,
      start: NaiveDateTime.utc_now(:second),
      timestamp: NaiveDateTime.utc_now(:second),
      is_bounce: false
    }

    session = struct!(default, overrides)
    key = {session.site_id, session.user_id}
    :peer.call(pid, Plausible.Cache.Adapter, :put, [:sessions, key, session, [dirty?: true]])
  end

  defp get_session(pid, key) do
    :peer.call(pid, Plausible.Cache.Adapter, :get, [:sessions, key])
  end

  defp await_transfer(pid, timeout \\ :timer.seconds(1)) do
    test = self()

    spawn_link(fn ->
      await_loop(fn -> :peer.call(pid, Plausible.Session.Transfer, :took?, []) end)
      send(test, :took)
    end)

    assert_receive :took, timeout
  end

  defp await_loop(f) do
    :timer.sleep(100)

    case f.() do
      true -> :done
      false -> await_loop(f)
    end
  end
end
