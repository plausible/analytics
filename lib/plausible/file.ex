defmodule Plausible.File do
  @moduledoc """
  File helpers for Plausible.
  """

  @doc """
  Moves a file from one location to another.

  Tries renaming first, and falls back to copying and deleting the original.
  """
  @spec mv!(Path.t(), Path.t()) :: :ok
  def mv!(source, destination) do
    File.rename!(source, destination)
  rescue
    e in File.RenameError ->
      try do
        case e.reason do
          # fallback to cp/rm for cross-device moves
          # https://github.com/plausible/analytics/issues/4638
          :exdev -> File.cp!(source, destination)
          _ -> reraise(e, __STACKTRACE__)
        end
      after
        File.rm(source)
      end
  end
end
