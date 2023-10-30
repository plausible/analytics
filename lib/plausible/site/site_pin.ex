defmodule Plausible.Site.SitePin do
  @moduledoc """
  Site pin schema
  """

  use Ecto.Schema

  @type t() :: %__MODULE__{}

  schema "site_pins" do
    belongs_to :user, Plausible.Auth.User
    belongs_to :site, Plausible.Site

    timestamps()
  end
end
