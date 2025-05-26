defmodule Plausible.Auth.SSO.Identity do
  @moduledoc """
  SSO Identity struct.
  """

  @type t() :: %__MODULE__{}

  @enforce_keys [:id, :name, :email, :expires_at]
  defstruct [:id, :name, :email, :expires_at]
end
