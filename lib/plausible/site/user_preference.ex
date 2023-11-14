defmodule Plausible.Site.UserPreference do
  @moduledoc """
  User-specific site preferences schema
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  @options [:pinned_at]

  schema "site_user_preferences" do
    field :pinned_at, :naive_datetime

    belongs_to :user, Plausible.Auth.User
    belongs_to :site, Plausible.Site

    timestamps()
  end

  defmacro options, do: @options

  def changeset(user, site, attrs \\ %{}) do
    %__MODULE__{}
    |> cast(attrs, @options)
    |> put_assoc(:user, user)
    |> put_assoc(:site, site)
  end
end
