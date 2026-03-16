defmodule Plausible.Teams.Memberships.UserPreference do
  @moduledoc """
  Team-specific user preferences schema
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  @options [:consolidated_view_cta_dismissed, :sort_index_options]

  defmodule SortIndexOptions do
    @moduledoc false

    use Ecto.Schema
    import Ecto.Changeset
    alias Plausible.Sites.Index

    @primary_key false
    embedded_schema do
      field :sort_by, Ecto.Enum, values: Index.sort_by_values(), default: :traffic
      field :sort_direction, Ecto.Enum, values: Index.sort_direction_values(), default: :desc
    end

    def changeset(struct \\ %__MODULE__{}, attrs) do
      struct
      |> cast(attrs, [:sort_by, :sort_direction])
      |> validate_inclusion(:sort_by, Index.sort_by_values())
      |> validate_inclusion(:sort_direction, Index.sort_direction_values())
    end
  end

  schema "team_membership_user_preferences" do
    field :consolidated_view_cta_dismissed, :boolean, default: false
    embeds_one :sort_index_options, SortIndexOptions, on_replace: :update

    belongs_to :team_membership, Plausible.Teams.Membership

    timestamps()
  end

  defmacro options, do: @options

  def changeset(team_membership, attrs \\ %{}) do
    %__MODULE__{}
    |> cast(attrs, [:consolidated_view_cta_dismissed])
    |> cast_embed(:sort_index_options)
    |> put_assoc(:team_membership, team_membership)
  end
end
