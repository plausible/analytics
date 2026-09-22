defmodule PlausibleWeb.Plugs.IgnoreTeamParam do
  @moduledoc """
  Drops the `__team` team switcher from the request params.

  `__team` is a first-party switcher: it only appears in URLs we compose
  ourselves, in emails and in-app links. `AuthPlug` lets it outrank the session
  when picking the current team, and persists the choice.

  The OAuth authorize screen is the one browser URL a third party composes in
  full, so the switcher has to be off there. Must run before `AuthPlug`.
  """
  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    update_in(conn.params, &Map.delete(&1, "__team"))
  end
end
