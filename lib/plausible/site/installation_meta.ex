defmodule Plausible.Site.InstallationMeta do
  @moduledoc """
  Embedded schema for installation meta-data
  """
  use Ecto.Schema

  alias Plausible.Site.TrackerScriptConfiguration

  @type t() :: %__MODULE__{}

  embedded_schema do
    field :installation_type, :string, default: "manual"
    field :script_config, :map, default: %{}
  end

  def to_tracker_script_configuration(site, installation_meta \\ nil) do
    installation_meta =
      installation_meta || site.installation_meta || %Plausible.Site.InstallationMeta{}

    %TrackerScriptConfiguration{
      site_id: site.id,
      installation_type:
        Map.get(installation_meta, :installation_type) |> remap_installation_type(),
      track_404_pages: Map.get(installation_meta.script_config, "404", false),
      hash_based_routing: Map.get(installation_meta.script_config, "hash", false),
      outbound_links: Map.get(installation_meta.script_config, "outbound-links", false),
      file_downloads: Map.get(installation_meta.script_config, "file-downloads", false),
      revenue_tracking: Map.get(installation_meta.script_config, "revenue", false),
      tagged_events: Map.get(installation_meta.script_config, "tagged-events", false),
      form_submissions: Map.get(installation_meta.script_config, "form-submissions", false),
      pageview_props: Map.get(installation_meta.script_config, "pageview-props", false)
    }
  end

  defp remap_installation_type("WordPress"), do: "wordpress"
  defp remap_installation_type("GTM"), do: "gtm"
  defp remap_installation_type(value), do: value
end
