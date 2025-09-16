defmodule PlausibleWeb.Tracker do
  @moduledoc """
  Helper module for building the dynamic tracker script. Used by PlausibleWeb.TrackerPlug.
  """

  use Plausible
  use Plausible.Repo
  alias Plausible.Site.TrackerScriptConfiguration

  path = Application.app_dir(:plausible, "priv/tracker/js/plausible-web.js")
  # On CI, the file might not be present for static checks so we create an empty one
  File.touch!(path)

  @plausible_main_script File.read!(path)
  @external_resource "priv/tracker/js/plausible-web.js"

  def scriptv2?(site, user \\ nil) do
    FunWithFlags.enabled?(:scriptv2, for: site) or FunWithFlags.enabled?(:scriptv2, for: user)
  end

  @spec get_plausible_main_script(String.t(), Keyword.t()) :: String.t() | nil
  def get_plausible_main_script(id, cache_opts \\ []) do
    on_ee do
      # On cloud:
      # 1. Check if tracker script ID is in the cache
      # 2. If it is, generate the script on the fly
      #
      # Note that EE is relying on CDN caching the script
      if PlausibleWeb.TrackerScriptCache.get(id, cache_opts) do
        get_tracker_script_configuration_by_id(id)
        |> build_script()
      end
    else
      # On self-hosted, we have a pre-warmed cache for the script
      PlausibleWeb.TrackerScriptCache.get(id, cache_opts)
    end
  end

  # Exposed for testing
  def plausible_main_config(tracker_script_configuration) do
    %{
      domain: tracker_script_configuration.site.domain,
      endpoint: tracker_ingestion_endpoint(),
      outboundLinks: tracker_script_configuration.outbound_links,
      fileDownloads: tracker_script_configuration.file_downloads,
      formSubmissions: tracker_script_configuration.form_submissions
    }
  end

  def build_script(%TrackerScriptConfiguration{} = tracker_script_configuration) do
    config_js_content =
      tracker_script_configuration
      |> plausible_main_config()
      |> Enum.flat_map(fn
        {key, value} when is_binary(value) -> ["#{key}:#{JSON.encode!(value)}"]
        # :TRICKY: Save bytes by using short-hand for true
        {key, true} -> ["#{key}:!0"]
        # Not enabled values can be omitted
        {_key, false} -> []
      end)
      |> Enum.sort_by(&String.length/1, :desc)
      |> Enum.join(",")

    @plausible_main_script
    |> String.replace("\"<%= @config_js %>\"", "{#{config_js_content}}")
  end

  def build_script(nil), do: nil

  def update_script_configuration(site, config_update, changeset_type) do
    Repo.transact(fn ->
      with {:ok, original_config} <- get_or_create_tracker_script_configuration(site),
           changeset <- changeset(original_config, config_update, changeset_type),
           {:ok, updated_config} <-
             Repo.update(changeset) do
        sync_goals(site, original_config, updated_config)

        on_ee do
          if should_purge_cache?(changeset) do
            purge_cache!(updated_config.id)
          end
        end

        {:ok, updated_config}
      end
    end)
  end

  on_ee do
    def purge_tracker_script_cache!(site) do
      tracker_script_configuration = get_or_create_tracker_script_configuration!(site)
      purge_cache!(tracker_script_configuration.id)
    end

    defp should_purge_cache?(changeset) do
      Map.keys(changeset.changes) != [:installation_type]
    end

    defp purge_cache!(config_id) do
      Plausible.Workers.PurgeCDNCache.new(
        %{id: config_id},
        # See PurgeCDNCache.ex for more details
        schedule_in: 10,
        replace: [scheduled: [:scheduled_at]]
      )
      |> Oban.insert!()
    end
  else
    def purge_tracker_script_cache!(_site), do: nil
  end

  def get_tracker_script_configuration(site) do
    Repo.get_by(TrackerScriptConfiguration, site_id: site.id)
  end

  def update_script_configuration!(site, config_update, changeset_type) do
    {:ok, updated_config} = update_script_configuration(site, config_update, changeset_type)
    updated_config
  end

  def get_or_create_tracker_script_configuration(site, params \\ %{}) do
    configuration = get_tracker_script_configuration(site)

    if configuration do
      {:ok, configuration}
    else
      Repo.transact(fn ->
        with {:ok, created_config} <-
               Repo.insert(
                 TrackerScriptConfiguration.installation_changeset(
                   %TrackerScriptConfiguration{site_id: site.id},
                   params
                 )
               ) do
          sync_goals(site, %{}, created_config)
          {:ok, created_config}
        end
      end)
    end
  end

  def get_or_create_tracker_script_configuration!(site, params \\ %{}) do
    {:ok, config} = get_or_create_tracker_script_configuration(site, params)
    config
  end

  on_ee do
    def supported_installation_types do
      ["manual", "wordpress", "gtm", "npm"]
    end
  else
    def supported_installation_types do
      ["manual", "wordpress", "npm"]
    end
  end

  def fallback_installation_type do
    "manual"
  end

  on_ee do
    import Ecto.Query

    defp get_tracker_script_configuration_by_id(id) do
      from(t in TrackerScriptConfiguration,
        where: t.id == ^id,
        join: s in assoc(t, :site),
        preload: [site: s]
      )
      |> Plausible.Repo.one()
    end
  end

  # Sync plausible goals with the updated script config
  defp sync_goals(site, original_config, updated_config) do
    [:track_404_pages, :outbound_links, :file_downloads, :form_submissions]
    |> Enum.map(fn key ->
      {key, Map.get(original_config, key, false), Map.get(updated_config, key, false)}
    end)
    |> Enum.each(fn
      {:track_404_pages, false, true} -> Plausible.Goals.create_404(site)
      {:track_404_pages, true, false} -> Plausible.Goals.delete_404(site)
      {:outbound_links, false, true} -> Plausible.Goals.create_outbound_links(site)
      {:outbound_links, true, false} -> Plausible.Goals.delete_outbound_links(site)
      {:file_downloads, false, true} -> Plausible.Goals.create_file_downloads(site)
      {:file_downloads, true, false} -> Plausible.Goals.delete_file_downloads(site)
      {:form_submissions, false, true} -> Plausible.Goals.create_form_submissions(site)
      {:form_submissions, true, false} -> Plausible.Goals.delete_form_submissions(site)
      _ -> nil
    end)
  end

  defp changeset(tracker_script_configuration, config_update, :installation) do
    TrackerScriptConfiguration.installation_changeset(tracker_script_configuration, config_update)
  end

  defp changeset(tracker_script_configuration, config_update, :plugins_api) do
    TrackerScriptConfiguration.plugins_api_changeset(tracker_script_configuration, config_update)
  end

  defp tracker_ingestion_endpoint() do
    # :TRICKY: Normally we would use PlausibleWeb.Endpoint.url() here, but
    # that requires the endpoint to be started. We start the TrackerScriptCache
    # before the endpoint is started, so we need to use the base_url directly.

    endpoint_config = Application.fetch_env!(:plausible, PlausibleWeb.Endpoint)
    base_url = Keyword.get(endpoint_config, :base_url)
    "#{base_url}/api/event"
  end
end
