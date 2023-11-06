defmodule Plausible.Site.UserPreference do
  @moduledoc """
  User-specific site preferences schema
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  defmodule Options do
    @moduledoc """
    Embed storing structured preferences
    """

    use Ecto.Schema
    import Ecto.Changeset

    embedded_schema do
      field :is_pinned, :boolean, default: false
    end

    def changeset(attrs \\ %{}) do
      cast(%__MODULE__{}, attrs, [:is_pinned])
    end
  end

  schema "site_user_preferences" do
    embeds_one :options, Options

    belongs_to :user, Plausible.Auth.User
    belongs_to :site, Plausible.Site

    timestamps()
  end

  def changeset(user, site, attrs \\ %{}) do
    embed_changeset = Options.changeset(attrs)

    %__MODULE__{}
    |> change()
    |> put_embed(:options, embed_changeset)
    |> put_assoc(:user, user)
    |> put_assoc(:site, site)
  end
end
