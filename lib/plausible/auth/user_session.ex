defmodule Plausible.Auth.UserSession do
  @moduledoc """
  Schema for storing user session data.
  """

  use Ecto.Schema

  @type t() :: %__MODULE__{}

  embedded_schema do
    field :user_id, :integer
  end
end
