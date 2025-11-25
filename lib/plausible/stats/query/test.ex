defmodule Plausible.Stats.Query.Test do
  @moduledoc """
  Module used in tests to 'set' the current time.
  """

  @now_key :__now

  def fix_now(now) do
    Process.put(@now_key, now)
  end

  def get_fixed_now() do
    Process.get(@now_key) || DateTime.utc_now(:second)
  end
end
