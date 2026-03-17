defmodule Plausible.Teams.Memberships.UserPreference do
  @moduledoc """
  Team-specific user preferences schema
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  @options [:consolidated_view_cta_dismissed, :sort_index_options]

  schema "team_membership_user_preferences" do
    field :consolidated_view_cta_dismissed, :boolean, default: false
    embeds_one :sort_index_options, Plausible.Sites.Index.UserPreference, on_replace: :update

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
