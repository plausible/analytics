defmodule Plausible.Random do
  @moduledoc """
  Methods for generating random numbers and strings.

  Unlike crypto module, this respects RANDOM_SEED env variable when seeding dev data.
  """

  @spec byte_int(pos_integer()) :: non_neg_integer()
  def byte_int(n) do
    if System.get_env("RANDOM_SEED") do
      limit = 2 ** (n * 8)
      :rand.uniform(limit)
    else
      :crypto.strong_rand_bytes(n) |> :binary.decode_unsigned()
    end
  end

  @spec binary(pos_integer()) :: binary()
  def binary(n) do
    if System.get_env("RANDOM_SEED") do
      bit_count = 8 * n
      <<byte_int(n)::size(bit_count)>>
    else
      :crypto.strong_rand_bytes(n)
    end
  end
end
