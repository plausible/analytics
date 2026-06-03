defmodule PlausibleWeb.Live.SiteTransferSettings.Form do
  @moduledoc """
  Form schema used by site transfer settings live view.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :destination, Ecto.Enum, values: [:team, :my_team, :account]
    field :team_identifier, :string
    field :email, :string
    field :my_team_available, :boolean, default: false
  end

  def changeset(params) do
    %__MODULE__{}
    |> cast(params, [:destination, :team_identifier, :my_team_available, :email])
    |> validate_required(:destination)
    |> validate_destination_fields()
  end

  defp validate_destination_fields(changeset) do
    case get_field(changeset, :destination) do
      :team ->
        validate_required(changeset, :team_identifier, message: "Please select a team")

      :account ->
        validate_required(changeset, :email, message: "Please enter an email address")

      :my_team ->
        changeset
    end
  end
end
