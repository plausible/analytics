defmodule Plausible.Site.TrackerScriptIdCacheTest do
  use Plausible.DataCase, async: false
  @moduletag :ee_only
  on_ee do
    alias Plausible.Site.TrackerScriptConfiguration
    alias Plausible.Site.TrackerScriptIdCache

    describe "public cache interface" do
      test "cache caches tracker scripts by id", %{test: test} do
        {:ok, _} =
          Supervisor.start_link(
            [
              {TrackerScriptIdCache,
               [
                 cache_name: test,
                 child_id: :test_cache_tracker_script,
                 ets_options: [read_concurrency: true]
               ]}
            ],
            strategy: :one_for_one,
            name: :"cache_supervisor_#{test}"
          )

        site = new_site(domain: "site1.example.com")
        config = create_config(site)

        :ok = TrackerScriptIdCache.refresh_all(cache_name: test)

        {:ok, _} = Plausible.Repo.delete(config)

        assert TrackerScriptIdCache.size(test) == 1

        assert TrackerScriptIdCache.get(config.id, force?: true, cache_name: test) == true

        refute TrackerScriptIdCache.get("nonexistent", cache_name: test, force?: true)
      end

      test "refresh all and put works", %{test: test} do
        {:ok, _} = start_test_cache(test)
        site1 = new_site()
        site2 = new_site()
        site3 = new_site()

        configs = [create_config(site1), create_config(site2)]
        cache_opts = [cache_name: test, force?: true]

        for config <- configs do
          assert TrackerScriptIdCache.get(config.id, cache_opts) == nil
        end

        assert :ok = TrackerScriptIdCache.refresh_all(cache_opts)

        for config <- configs do
          result = TrackerScriptIdCache.get(config.id, cache_opts)
          assert result == true
        end

        new_config = create_config(site3)

        TrackerScriptIdCache.broadcast_put(
          new_config.id,
          true,
          cache_opts
        )

        # wait for broadcast put to take effect
        assert eventually(fn ->
                 result = TrackerScriptIdCache.get(new_config.id, cache_opts)
                 {result == true, result}
               end)

        for config <- [new_config | configs] do
          result = TrackerScriptIdCache.get(config.id, cache_opts)
          assert result == true
        end
      end

      test "refreshes only recently added configurations", %{test: test} do
        {:ok, _} = start_test_cache(test)

        site1 = new_site()
        site2 = new_site()

        past_date = ~N[2021-01-01 00:00:00]
        old_config = create_config(site1, inserted_at: past_date, updated_at: past_date)
        new_config = create_config(site2)

        cache_opts = [cache_name: test, force?: true]

        assert TrackerScriptIdCache.get(old_config.id, cache_opts) == nil
        assert TrackerScriptIdCache.get(new_config.id, cache_opts) == nil

        assert :ok = TrackerScriptIdCache.refresh_updated_recently(cache_opts)

        refute TrackerScriptIdCache.get(old_config.id, cache_opts)
        assert TrackerScriptIdCache.get(new_config.id, cache_opts)
      end
    end

    defp start_test_cache(cache_name) do
      %{start: {m, f, a}} =
        TrackerScriptIdCache.child_spec(cache_name: cache_name, ets_options: [:bag])

      apply(m, f, a)
    end

    defp create_config(site, opts \\ []) do
      config = %TrackerScriptConfiguration{
        site_id: site.id,
        installation_type: :manual,
        hash_based_routing: true,
        outbound_links: true,
        file_downloads: true,
        form_submissions: true
      }

      config
      |> Ecto.Changeset.change(opts)
      |> Repo.insert!()
      |> Repo.preload(:site)
    end
  end
end
