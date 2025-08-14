defmodule Plausible.InstallationSupport.Result do
  @moduledoc """
  Diagnostics interpretation result.

  ## Example
  ok?: false,
  data: nil,
  errors: [error.message],
  recommendations: [%{text: error.recommendation, url: error.url}]

  ok?: true,
  data: %{},
  errors: [],
  recommendations: []
  """
  defstruct ok?: false, errors: [], recommendations: [], data: nil
  @type t :: %__MODULE__{}
end
