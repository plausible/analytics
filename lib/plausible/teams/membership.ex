defmodule Plausible.Teams.Membership do
  @moduledoc """
  Team membership schema
  """

  use Ecto.Schema

  import Ecto.Changeset

  @roles [:guest, :viewer, :editor, :admin, :owner]

  @type t() :: %__MODULE__{}

  schema "team_memberships" do
    field :role, Ecto.Enum, values: @roles

    belongs_to :user, Plausible.Auth.User
    belongs_to :team, Plausible.Teams.Team

    has_many :guest_memberships, Plausible.Teams.GuestMembership, foreign_key: :team_membership_id

    timestamps()
  end

  def roles(), do: @roles

  def changeset(team, user, role) do
    %__MODULE__{}
    |> change()
    |> put_change(:role, role)
    |> put_assoc(:team, team)
    |> put_assoc(:user, user)
    |> unique_constraint(:user_id, name: :one_team_per_user)
  end
end
