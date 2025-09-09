defmodule Plausible.Times do
  @moduledoc """
  API for working with time wrapping around external libraries where necessary.
  """

  @spec today(String.t()) :: Date.t()
  def today(tz) do
    tz
    |> DateTime.now!()
    |> DateTime.to_date()
  end
end
