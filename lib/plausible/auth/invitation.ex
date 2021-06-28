defmodule Plausible.Auth.Invitation do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:invitation_id, :role, :site]}
  @required [:email, :role, :site_id, :inviter_id]
  schema "invitations" do
    field :invitation_id, :string
    field :email, :string
    field :role, Ecto.Enum, values: [:owner, :admin, :viewer]

    belongs_to :inviter, Plausible.Auth.User
    belongs_to :site, Plausible.Site

    timestamps()
  end

  def new(attrs \\ %{}) do
    %__MODULE__{invitation_id: Nanoid.generate()}
    |> cast(attrs, @required)
    |> validate_required(@required)
  end
end
