defmodule Plausible.Site.Preference do
  @moduledoc """
  Site pin schema
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  defmodule Preferences do
    use Ecto.Schema
    import Ecto.Changeset

    embedded_schema do
      field :is_pinned, :boolean, default: false
    end

    def changeset(attrs \\ %{}) do
      cast(%__MODULE__{}, attrs, [:is_pinned])
    end
  end

  schema "site_preferences" do
    embeds_one :preferences, Preferences

    belongs_to :user, Plausible.Auth.User
    belongs_to :site, Plausible.Site

    timestamps()
  end

  def changeset(user, site, attrs \\ %{}) do
    embed_changeset = Preferences.changeset(attrs)

    %__MODULE__{}
    |> change()
    |> put_embed(:preferences, embed_changeset)
    |> put_assoc(:user, user)
    |> put_assoc(:site, site)
  end
end
