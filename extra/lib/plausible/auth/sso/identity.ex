defmodule Plausible.Auth.SSO.Identity do
  @moduledoc """
  SSO Identity struct.
  """

  @type t() :: %__MODULE__{}

  @derive Plausible.Audit.Encoder
  @enforce_keys [:id, :integration_id, :name, :email, :expires_at]
  defstruct [:id, :integration_id, :name, :email, :expires_at]
end
