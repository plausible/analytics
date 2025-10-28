defmodule Plausible.CondolidatedView.CacheTestSync do
  use Plausible.DataCase, async: false
  use Plausible.Teams.Test

  on_ee do
    alias Plausible.ConsolidatedView.Cache

    setup do
      Sentry.put_config(:test_mode, true)

      on_exit(fn ->
        Sentry.put_config(:test_mode, false)
      end)
    end

    test "big views get cropped up to 14k", %{test: test} do
      assert :ok = Sentry.Test.start_collecting_sentry_reports()
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
  end

  defp start_test_cache(cache_name) do
    %{start: {m, f, a}} = Cache.child_spec(cache_name: cache_name)
    apply(m, f, a)
  end
end
