defmodule PlausibleWeb.TrackerScriptCacheTest do
  use Plausible.DataCase, async: false

  alias Plausible.Site.TrackerScriptConfiguration
  alias PlausibleWeb.TrackerScriptCache

  describe "public cache interface" do
    test "cache caches tracker scripts by id", %{test: test} do
      {:ok, _} =
        Supervisor.start_link(
          [
            {TrackerScriptCache,
             [
               cache_name: test,
               child_id: :test_cache_tracker_script,
               ets_options: [:bag, read_concurrency: true]
             ]}
          ],
          strategy: :one_for_one,
          name: :"cache_supervisor_#{test}"
        )

      site = new_site(domain: "site1.example.com")
      config = create_config(site)

      :ok = TrackerScriptCache.refresh_all(cache_name: test)

      {:ok, _} = Plausible.Repo.delete(config)

      assert TrackerScriptCache.size(test) == 1

      assert result = TrackerScriptCache.get(config.id, force?: true, cache_name: test)

      on_ee do
        assert result == true
      else
        # it's the script
        assert is_binary(result)
        # the config has been expanded into the script template
        assert result =~ ~r/domain:\"#{site.domain}\"/
      end

      refute TrackerScriptCache.get("nonexistent", cache_name: test, force?: true)
    end

    test "refresh all and broadcast put works", %{test: test} do
      {:ok, _} = start_test_cache(test)
      site1 = new_site()
      site2 = new_site()

      configs = [create_config(site1), create_config(site2)]
      cache_opts = [cache_name: test, force?: true]

      for config <- configs do
        assert TrackerScriptCache.get(config.id, cache_opts) == nil
      end

      assert :ok = TrackerScriptCache.refresh_all(cache_opts)

      for config <- configs do
        result = TrackerScriptCache.get(config.id, cache_opts)

        on_ee do
          assert result == true
        else
          assert is_binary(result)
          assert result =~ ~r/domain:\"#{config.site.domain}\"/
          assert result =~ ~r/fileDownloads:\!0/
        end
      end

      [%TrackerScriptConfiguration{} = updated_config | _] = configs

      TrackerScriptCache.broadcast_put(
        updated_config.id,
        TrackerScriptCache.cache_content(%TrackerScriptConfiguration{
          updated_config
          | file_downloads: false
        }),
        cache_opts
      )

      on_ce do
        # wait for broadcast put to take effect
        assert eventually(fn ->
                 result = TrackerScriptCache.get(updated_config.id, cache_opts)

                 {!(result =~ ~r/fileDownloads:\!0/), result}
               end)
      end

      for config <- configs do
        result = TrackerScriptCache.get(config.id, cache_opts)

        on_ee do
          assert result == true
        else
          assert result =~
                   ~r/domain:\"#{config.site.domain}\"/
        end
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

      assert TrackerScriptCache.get(old_config.id, cache_opts) == nil
      assert TrackerScriptCache.get(new_config.id, cache_opts) == nil

      assert :ok = TrackerScriptCache.refresh_updated_recently(cache_opts)

      refute TrackerScriptCache.get(old_config.id, cache_opts)
      assert TrackerScriptCache.get(new_config.id, cache_opts)
    end
  end

  defp start_test_cache(cache_name) do
    %{start: {m, f, a}} = TrackerScriptCache.child_spec(cache_name: cache_name)
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
