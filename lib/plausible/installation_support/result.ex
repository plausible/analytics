defmodule Plausible.InstallationSupport.Result do
  @moduledoc """
  Diagnostics interpretation result.

  ## Example
  ok?: false
  errors: [error.message],
  recommendations: [%{text: error.recommendation, url: error.url}]

  """
  defstruct ok?: false, errors: [], recommendations: []
  @type t :: %__MODULE__{}
end
