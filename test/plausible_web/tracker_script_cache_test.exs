defmodule PlausibleWeb.TrackerScriptCacheTest do
  use Plausible.DataCase, async: true
  use Plausible.Teams.Test

  alias Plausible.Site.TrackerScriptConfiguration
  alias PlausibleWeb.TrackerScriptCache

  describe "public cache interface" do
    test "cache caches tracker script configurations", %{test: test} do
      {:ok, _} =
        Supervisor.start_link(
          [{TrackerScriptCache, [cache_name: test, child_id: :test_cache_tracker_script]}],
          strategy: :one_for_one,
          name: :"cache_supervisor_#{test}"
        )

      site = new_site(domain: "site1.example.com")
      config = create_config(site)

      :ok = TrackerScriptCache.refresh_all(cache_name: test)

      {:ok, _} = Plausible.Repo.delete(config)

      assert TrackerScriptCache.size(test) == 1

      assert script_tag = TrackerScriptCache.get(config.id, force?: true, cache_name: test)
      assert is_binary(script_tag)

      refute TrackerScriptCache.get("nonexistent", cache_name: test, force?: true)
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
