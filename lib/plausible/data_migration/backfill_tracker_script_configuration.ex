defmodule Plausible.DataMigration.BackfillTrackerScriptConfiguration do
  @moduledoc """
  Backfill Plausible.Site.TrackerScriptConfiguration for all sites.
  """

  import Ecto.Query

  alias Plausible.Repo

  defmodule TrackerScriptConfigurationSnapshot do
    @moduledoc """
    A snapshot of the Plausible.Site.TrackerScriptConfiguration schema from May 2025.
    """

    use Ecto.Schema

    @primary_key false
    schema "tracker_script_configuration" do
      field :id, :string
      field :installation_type, Ecto.Enum, values: [:manual, :wordpress, :gtm, nil]

      field :track_404_pages, :boolean, default: false
      field :hash_based_routing, :boolean, default: false
      field :outbound_links, :boolean, default: false
      field :file_downloads, :boolean, default: false
      field :revenue_tracking, :boolean, default: false
      field :tagged_events, :boolean, default: false
      field :form_submissions, :boolean, default: false
      field :pageview_props, :boolean, default: false

      field :site_id, :integer

      timestamps()
    end
  end

  def run() do
    now = NaiveDateTime.utc_now(:second)
    process_batch(0, now)
  end

  @batch_size 1000

  def process_batch(offset, now) do
    sites =
      Repo.all(
        from(s in Plausible.Site, order_by: [asc: :id], limit: @batch_size, offset: ^offset)
      )

    if length(sites) > 0 do
      create_tracker_script_configurations(sites, now)
      process_batch(offset + @batch_size, now)
    end
  end

  defp create_tracker_script_configurations(sites, now) do
    configurations = Enum.map(sites, &tracker_script_configuration(&1, now))

    Repo.insert_all(
      TrackerScriptConfigurationSnapshot,
      configurations,
      # Conflicts mean that the site has already been updated and is in sync
      on_conflict: :nothing,
      conflict_target: [:site_id]
    )
  end

  defp tracker_script_configuration(site, now) do
    installation_meta = site.installation_meta
    installation_type = if(installation_meta, do: installation_meta.installation_type, else: nil)
    script_config = if(installation_meta, do: installation_meta.script_config, else: %{})

    %{
      id: Nanoid.generate(),
      site_id: site.id,
      installation_type: installation_type |> remap_installation_type(),
      track_404_pages: Map.get(script_config, "404", false),
      hash_based_routing: Map.get(script_config, "hash", false),
      outbound_links: Map.get(script_config, "outbound-links", false),
      file_downloads: Map.get(script_config, "file-downloads", false),
      revenue_tracking: Map.get(script_config, "revenue", false),
      tagged_events: Map.get(script_config, "tagged-events", false),
      form_submissions: Map.get(script_config, "form-submissions", false),
      pageview_props: Map.get(script_config, "pageview-props", false),
      inserted_at: now,
      updated_at: now
    }
  end

  defp remap_installation_type("WordPress"), do: :wordpress
  defp remap_installation_type("GTM"), do: :gtm
  defp remap_installation_type("manual"), do: :manual
  defp remap_installation_type(nil), do: nil
end
