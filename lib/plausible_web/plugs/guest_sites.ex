defmodule PlausibleWeb.Plugs.GuestSites do
  @moduledoc """
  Assigns `has_guest_sites?` for the account settings sidebar, which only
  links to the "Guest sites" page when the user is a guest of any site.

  LiveView settings pages get the same assign from
  `PlausibleWeb.Live.SettingsContext`.
  """

  def init(_), do: []

  def call(conn, _) do
    Plug.Conn.assign(
      conn,
      :has_guest_sites?,
      Plausible.Teams.Memberships.has_guest_memberships?(conn.assigns.current_user)
    )
  end
end
