defmodule Plausible.Teams.UserPreference do
  @moduledoc """
  Team-specific user preferences schema
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  @options [:consolidated_view_cta_dismissed]

  schema "team_user_preferences" do
    field :consolidated_view_cta_dismissed, :boolean, default: false

    belongs_to :team, Plausible.Teams.Team
    belongs_to :user, Plausible.Auth.User

    timestamps()
  end

  defmacro options, do: @options

  def changeset(user, team, attrs \\ %{}) do
    %__MODULE__{}
    |> cast(attrs, @options)
    |> put_assoc(:user, user)
    |> put_assoc(:team, team)
  end
end
