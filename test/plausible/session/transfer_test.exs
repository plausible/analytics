defmodule Plausible.Session.TransferTest do
  use ExUnit.Case
  import Plausible.Factory
  import Plausible.TestUtils, only: [tmp_dir: 0]

  @tag :slow
  test "it works" do
    tmp_dir = tmp_dir()

    old = start_another_plausible(tmp_dir)
    await_transfer(old)

    Enum.each(1..250, fn _ -> process_event(old, build(:event, name: "pageview")) end)

    :ok = :peer.call(old, Plausible.Session.WriteBuffer, :flush, [])
    :ok = :peer.call(old, Plausible.Event.WriteBuffer, :flush, [])

    old_sessions_sorted = all_sessions_sorted(old)

    new = start_another_plausible(tmp_dir)

    await_transfer(new)

    assert all_sessions_sorted(old) == []
    assert all_sessions_sorted(new) == old_sessions_sorted
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

  @session_params %{
    referrer: "ref",
    referrer_source: "refsource",
    utm_medium: "medium",
    utm_source: "source",
    utm_campaign: "campaign",
    utm_content: "content",
    utm_term: "term",
    browser: "browser",
    browser_version: "55",
    country_code: "EE",
    screen_size: "Desktop",
    operating_system: "Mac",
    operating_system_version: "11"
  }

  defp process_event(pid, event) do
    :peer.call(pid, Plausible.Session.CacheStore, :on_event, [
      event,
      @session_params,
      _prev_user_id = nil,
      [buffer_insert: &Function.identity/1]
    ])
  end

  defp all_sessions_sorted(pid) do
    cache_names = :peer.call(pid, Plausible.Cache.Adapter, :get_names, [:sessions])

    records =
      Enum.flat_map(cache_names, fn cache_name ->
        tab = :peer.call(pid, ConCache, :ets, [cache_name])
        :peer.call(pid, :ets, :tab2list, [tab])
      end)

    Enum.sort_by(records, fn {key, _} -> key end)
  end

  defp await_transfer(pid, timeout \\ :timer.seconds(1)) do
    test = self()

    spawn_link(fn ->
      await_loop(fn -> :peer.call(pid, Plausible.Session.Transfer, :attempted?, []) end)
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
