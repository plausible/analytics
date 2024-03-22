defmodule Plausible.Helpers.JSON do
  @moduledoc """
  Common helpers for JSON handling
  """

  def decode_or_fallback(raw) do
    with raw when is_binary(raw) <- raw,
         {:ok, %{} = decoded} <- Jason.decode(raw) do
      decoded
    else
      already_a_map when is_map(already_a_map) -> already_a_map
      _any -> %{}
    end
  end
end
