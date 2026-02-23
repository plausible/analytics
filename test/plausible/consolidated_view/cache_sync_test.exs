defmodule Plausible.CondolidatedView.CacheSyncTest do
  use Plausible.DataCase, async: false

  on_ee do
    alias Plausible.ConsolidatedView.Cache

    setup %{test_pid: test_pid} do
      Plausible.Test.Support.Sentry.setup(test_pid)
    end

    test "big views get cropped up to 14k", %{test: test} do
      {:ok, _pid} = start_test_cache(test)

      Plausible.Cache.Adapter.put(test, "key", Enum.to_list(1..20_000))
      site_ids = Cache.get("key", cache_name: test, force?: true)
      assert length(site_ids) == 14_000

      assert [
               %{
                 extra: %{key: "key", sites: 20_000},
                 message: %{formatted: "Consolidated View crop warning"}
               }
             ] = Sentry.Test.pop_sentry_reports()
    end

    defp start_test_cache(cache_name) do
      %{start: {m, f, a}} = Cache.child_spec(cache_name: cache_name)
      apply(m, f, a)
    end
  end
end
