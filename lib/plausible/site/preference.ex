defmodule Plausible.Site.Preference do
  @moduledoc """
  Site pin schema
  """

  use Ecto.Schema

  @type t() :: %__MODULE__{}

  defmodule Preferences do
    use Ecto.Schema

    embedded_schema do
      field :is_pinned, :boolean, default: false
    end
  end

  schema "site_preferences" do
    embeds_one :preferences, Preferences

    belongs_to :user, Plausible.Auth.User
    belongs_to :site, Plausible.Site

    timestamps()
  end
end
