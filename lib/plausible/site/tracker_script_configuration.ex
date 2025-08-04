defmodule Plausible.Site.TrackerScriptConfiguration do
  @moduledoc """
  Schema for tracker script configuration
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{}
  @derive {Jason.Encoder,
           only: [
             :id,
             :installation_type,
             :track_404_pages,
             :hash_based_routing,
             :outbound_links,
             :file_downloads,
             :revenue_tracking,
             :tagged_events,
             :form_submissions,
             :pageview_props
           ]}

  @primary_key {:id, Plausible.Ecto.Types.Nanoid, autogenerate: true}
  schema "tracker_script_configuration" do
    field :installation_type, Ecto.Enum, values: [:manual, :wordpress, :gtm, nil]

    field :track_404_pages, :boolean, default: false
    field :hash_based_routing, :boolean, default: false
    field :outbound_links, :boolean, default: false
    field :file_downloads, :boolean, default: false
    field :revenue_tracking, :boolean, default: false
    field :tagged_events, :boolean, default: false
    field :form_submissions, :boolean, default: false
    field :pageview_props, :boolean, default: false

    belongs_to :site, Plausible.Site

    timestamps()
  end

  def installation_changeset(struct, params) do
    struct
    |> cast(params, [
      :installation_type,
      :track_404_pages,
      :hash_based_routing,
      :outbound_links,
      :file_downloads,
      :revenue_tracking,
      :tagged_events,
      :form_submissions,
      :pageview_props,
      :site_id
    ])
    |> validate_required([:site_id])
  end

  def plugins_api_changeset(struct, params) do
    struct
    |> cast(params, [
      :installation_type,
      :hash_based_routing,
      :outbound_links,
      :file_downloads,
      :form_submissions,
      :site_id
    ])
    |> validate_required([:site_id])
  end
end
