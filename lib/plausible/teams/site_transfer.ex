defmodule Plausible.Teams.SiteTransfer do
  @moduledoc """
  Site transfer schema
  """

  use Ecto.Schema

  import Ecto.Changeset

  schema "team_site_transfers" do
    field :transfer_id, :string
    field :email, :string
    field :transfer_guests, :boolean, default: true

    belongs_to :site, Plausible.Site
    belongs_to :initiator, Plausible.Auth.User
    belongs_to :destination_team, Plausible.Teams.Team

    timestamps()
  end

  def changeset(site, opts) do
    initiator = Keyword.fetch!(opts, :initiator)
    transfer_guests = Keyword.get(opts, :transfer_guests, true)
    destination_team = Keyword.get(opts, :destination_team)
    email = Keyword.get(opts, :email)

    %__MODULE__{transfer_id: Nanoid.generate()}
    |> cast(%{email: email}, [:email])
    |> put_change(:transfer_guests, transfer_guests)
    |> put_assoc(:site, site)
    |> put_assoc(:destination_team, destination_team)
    |> put_assoc(:initiator, initiator)
  end
end
