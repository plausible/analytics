defmodule PlausibleWeb.Tracker do
  @moduledoc """
  Helper module for building the dynamic tracker script. Used by PlausibleWeb.TrackerPlug.
  """

  use Plausible.Repo
  alias Plausible.Site.TrackerScriptConfiguration

  path = Application.app_dir(:plausible, "priv/tracker/js/plausible-main.js")
  # On CI, the file might not be present for static checks so we create an empty one
  File.touch!(path)

  @plausible_main_script File.read!(path)
  @external_resource "priv/tracker/js/plausible-main.js"

  def plausible_main_script_tag(tracker_script_configuration) do
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

  def plausible_main_config(tracker_script_configuration) do
    %{
      domain: tracker_script_configuration.site.domain,
      endpoint: "#{PlausibleWeb.Endpoint.url()}/api/event",
      hash: tracker_script_configuration.hash_based_routing,
      outboundLinks: tracker_script_configuration.outbound_links,
      fileDownloads: tracker_script_configuration.file_downloads,
      taggedEvents: tracker_script_configuration.tagged_events,
      revenue: tracker_script_configuration.revenue_tracking,
      # Options not directly exposed via onboarding
      local: false,
      manual: false
    }
  end

  def update_script_configuration(site, config_update) do
    {:ok, updated_config} = TrackerScriptConfiguration.upsert(config_update)

    sync_goals(site, config_update)

    updated_config
  end

  # Sync plausible goals with the updated script config
  defp sync_goals(site, config_update) do
    config_update
    |> Enum.map(fn {key, value} -> {to_atom(key), value} end)
    |> Enum.each(fn
      {:track_404_pages, true} -> Plausible.Goals.create_404(site)
      {:track_404_pages, false} -> Plausible.Goals.delete_404(site)
      {:outbound_links, true} -> Plausible.Goals.create_outbound_links(site)
      {:outbound_links, false} -> Plausible.Goals.delete_outbound_links(site)
      {:file_downloads, true} -> Plausible.Goals.create_file_downloads(site)
      {:file_downloads, false} -> Plausible.Goals.delete_file_downloads(site)
      _ -> nil
    end)
  end

  defp to_atom(str) when is_binary(str), do: String.to_existing_atom(str)
  defp to_atom(atom) when is_atom(atom), do: atom
end
