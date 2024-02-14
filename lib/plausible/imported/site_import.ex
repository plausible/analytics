defmodule Plausible.Imported.SiteImport do
  @moduledoc """
  Site import schema.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Plausible.Auth.User
  alias Plausible.Imported.ImportSources
  alias Plausible.Site

  @statuses [:pending, :importing, :completed, :failed]

  @type t() :: %__MODULE__{}

  schema "site_imports" do
    field :start_date, :date
    field :end_date, :date
    field :source, Ecto.Enum, values: ImportSources.names()
    field :status, Ecto.Enum, values: @statuses
    field :legacy, :boolean

    belongs_to :site, Site
    belongs_to :imported_by, User

    timestamps()
  end

  for status <- @statuses do
    defmacro unquote(status)(), do: unquote(status)
  end

  # NOTE: this is necessary for backwards compatibility
  # with legacy imports
  @spec label(t() | Site.ImportedData.t()) :: String.t()
  def label(%__MODULE__{source: source}), do: ImportSources.by_name(source).label()
  def label(%Site.ImportedData{source: source}), do: source

  @spec from_legacy(Site.ImportedData.t()) :: t()
  def from_legacy(%Site.ImportedData{} = data) do
    status =
      cond do
        data.status == "ok" -> completed()
        data.status == "error" -> failed()
        true -> importing()
      end

    %__MODULE__{
      legacy: true,
      start_date: data.start_date,
      end_date: data.end_date,
      source: :universal_analytics,
      status: status
    }
  end

  @spec create_changeset(Site.t(), User.t(), map()) :: Ecto.Changeset.t()
  def create_changeset(site, user, params) do
    %__MODULE__{}
    |> cast(params, [:source, :start_date, :end_date, :legacy])
    |> validate_required([:source])
    |> put_assoc(:site, site)
    |> put_assoc(:imported_by, user)
    |> put_change(:status, pending())
  end

  @spec start_changeset(t()) :: Ecto.Changeset.t()
  def start_changeset(site_import) do
    site_import
    |> change(status: importing())
  end

  @spec complete_changeset(t(), map()) :: Ecto.Changeset.t()
  def complete_changeset(site_import, params \\ %{}) do
    site_import
    |> cast(params, [:start_date, :end_date])
    |> put_change(:status, completed())
    |> validate_required([:start_date, :end_date])
  end

  @spec fail_changeset(t()) :: Ecto.Changeset.t()
  def fail_changeset(site_import) do
    change(site_import, status: failed())
  end
end
