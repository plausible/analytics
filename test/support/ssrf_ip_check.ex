defmodule Plausible.Test.Support.SSRFIPCheck do
  @moduledoc """
  Allows 127.0.0.1 so tests can reach a local server; defers everything else to
  `Plausible.IP.Tools`, unlike `allow_reserved_ips?` which allows all.
  """

  @behaviour Plausible.IP.ToolsInterface

  @impl true
  def allowed?({127, 0, 0, 1}), do: true
  def allowed?(ip), do: Plausible.IP.Tools.allowed?(ip)
end
