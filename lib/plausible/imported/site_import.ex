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
    field :label, :string
    field :source, Ecto.Enum, values: ImportSources.names()
    field :status, Ecto.Enum, values: @statuses
    field :legacy, :boolean, default: false
    field :has_scroll_depth, :boolean, default: false

    belongs_to :site, Site
    belongs_to :imported_by, User

    timestamps()
  end

  for status <- @statuses do
    defmacro unquote(status)(), do: unquote(status)
  end

  @spec label(t()) :: String.t()
  def label(%{source: source, label: label}) do
    build_label(ImportSources.by_name(source).label(), label)
  end

  @spec create_changeset(Site.t(), User.t(), map()) :: Ecto.Changeset.t()
  def create_changeset(site, user, params) do
    %__MODULE__{}
    |> cast(params, [:label, :source, :start_date, :end_date, :legacy])
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

  defp build_label(source, nil), do: source
  defp build_label(source, label), do: "#{source} (#{label})"
end
