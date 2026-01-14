defmodule Plausible.Test.Support.Sandbox do
  @moduledoc """
  Prevent background processes from interfering with tests 
  (e.g. exiting before properly returning the connection) by allowing them to access sandbox
  """
  def allow_salts_process do
    case Process.whereis(Plausible.Session.Salts) do
      nil ->
        :ok

      pid ->
        Ecto.Adapters.SQL.Sandbox.allow(Plausible.Repo, self(), pid)
    end
  end
end
