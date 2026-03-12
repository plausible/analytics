defmodule Plausible.Teams.Memberships.UserPreference do
  @moduledoc """
  Team-specific user preferences schema
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  @options [:consolidated_view_cta_dismissed, :sites_sort_by, :sites_sort_direction]

  schema "team_membership_user_preferences" do
    field :consolidated_view_cta_dismissed, :boolean, default: false
    field :sites_sort_by, :string, default: nil
    field :sites_sort_direction, :string, default: nil

    belongs_to :team_membership, Plausible.Teams.Membership

    timestamps()
  end

  defmacro options, do: @options

  def changeset(team_membership, attrs \\ %{}) do
    %__MODULE__{}
    |> cast(attrs, @options)
    |> put_assoc(:team_membership, team_membership)
  end
end
