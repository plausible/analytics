defmodule Plausible.InstallationSupport.Result do
  @moduledoc """
  Diagnostics interpretation result.
  """
  defstruct ok?: false, errors: [], recommendations: []
  @type t :: %__MODULE__{}
end
