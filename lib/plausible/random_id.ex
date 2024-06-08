defmodule Plausible.RandomID do
  @moduledoc """
  Generates short random string.

  Useful as a unique element of ID properties in LV components.

  Routine for generation borrowed from `Phoenix.LiveView`.
  """

  @spec generate() :: String.t()
  def generate() do
    random_encoded_bytes()
    |> String.replace(["/", "+"], "-")
    |> String.downcase()
  end

  defp random_encoded_bytes() do
    binary = <<
      System.system_time(:nanosecond)::64,
      :erlang.phash2({node(), self()})::16,
      :erlang.unique_integer()::16
    >>

    Base.url_encode64(binary)
  end
end
