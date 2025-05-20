defmodule Plausible.Site.TrackerScriptConfiguration do
  @moduledoc """
  Schema for tracker script configuration
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @type t() :: %__MODULE__{}

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

  def changeset(struct, params) do
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

  def upsert(configuration_map) do
    changeset = changeset(%__MODULE__{}, configuration_map)

    Plausible.Repo.insert(
      changeset,
      on_conflict: {:replace, fields_to_update(configuration_map)},
      conflict_target: [:site_id],
      returning: true
    )
  end

  def get_or_create!(site_id) do
    existing_configuration =
      Plausible.Repo.one(
        from(c in Plausible.Site.TrackerScriptConfiguration, where: c.site_id == ^site_id)
      )

    if existing_configuration do
      existing_configuration
    else
      {:ok, new_configuration} = upsert(%{site_id: site_id})
      new_configuration
    end
  end

  defp fields_to_update(configuration_map) do
    fields = __MODULE__.__schema__(:fields)

    configuration_map
    |> Map.keys()
    |> Enum.map(fn
      key when is_atom(key) -> key
      key when is_binary(key) -> String.to_existing_atom(key)
    end)
    |> Enum.filter(&(&1 in fields))
    |> Enum.concat([:updated_at])
  end
end
