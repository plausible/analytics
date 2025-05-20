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

  def plausible_main_script_tag(site) do
    config_js_content =
      site
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

  def plausible_main_config(site) do
    script_config = site.installation_meta.script_config

    %{
      domain: site.domain,
      endpoint: "#{PlausibleWeb.Endpoint.url()}/api/event",
      hash: Map.get(script_config, "hash", false),
      outboundLinks: Map.get(script_config, "outbound-links", false),
      fileDownloads: Map.get(script_config, "file-downloads", false),
      taggedEvents: Map.get(script_config, "tagged-events", false),
      revenue: Map.get(script_config, "revenue", false),
      # Options not directly exposed via onboarding
      local: false,
      manual: false
    }
  end

  def update_script_configuration(site, config_update) do
    installation_meta_update = to_installation_meta(config_update)

    Repo.transaction(fn ->
      Plausible.Sites.update_installation_meta!(site, installation_meta_update)
      {:ok, _} = TrackerScriptConfiguration.upsert(config_update)

      update_goals(site, config_update)
    end)
  end

  # Sync plausible goals with the updated script config
  defp update_goals(site, config_update) do
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

  defp to_installation_meta(config_update) do
    %{
      installation_type: remap_installation_type(config_update["installation_type"]),
      script_config: %{
        "404" => Map.get(config_update, "track_404_pages", false),
        "hash" => Map.get(config_update, "hash_based_routing", false),
        "outbound-links" => Map.get(config_update, "outbound_links", false),
        "file-downloads" => Map.get(config_update, "file_downloads", false),
        "revenue" => Map.get(config_update, "revenue_tracking", false),
        "tagged-events" => Map.get(config_update, "tagged_events", false),
        "pageview-props" => Map.get(config_update, "pageview_props", false)
      }
    }
  end

  defp remap_installation_type("wordpress"), do: "WordPress"
  defp remap_installation_type("gtm"), do: "GTM"
  defp remap_installation_type(value), do: value

  defp to_atom(str) when is_binary(str), do: String.to_existing_atom(str)
  defp to_atom(atom) when is_atom(atom), do: atom
end
