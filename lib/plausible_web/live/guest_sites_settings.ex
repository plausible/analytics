defmodule PlausibleWeb.Live.GuestSitesSettings do
  @moduledoc """
  LiveView listing all user's guest sites with the ability to leave them.
  Without any guest memberships, the page redirects and the sidebar link
  to it is hidden.
  """

  use PlausibleWeb, :live_view

  alias Plausible.Teams

  def mount(_params, _session, socket) do
    {:ok, load_guest_memberships(socket)}
  end

  def render(assigns) do
    ~H"""
    <.flash_messages flash={@flash} />

    <.settings_tiles>
      <.tile docs="users-roles">
        <:title>Guest sites</:title>
        <:subtitle>
          Sites you've been invited to as a guest. Leaving a site removes your access to its stats.
        </:subtitle>

        <div id="guest-site-list">
          <div
            :for={guest_membership <- @guest_memberships}
            id={"guest-site-#{guest_membership.site.id}"}
            class="mt-6 first:mt-0 flex items-center gap-x-3 sm:gap-x-5"
          >
            <PlausibleWeb.Live.Sites.favicon domain={guest_membership.site.domain} />
            <div class="flex flex-col min-w-0">
              <span class="text-sm font-medium truncate text-gray-900 dark:text-gray-100">
                {guest_membership.site.domain}
              </span>
              <span class="text-gray-500 text-xs truncate">
                {owned_by(guest_membership.site.team)}
              </span>
            </div>
            <div class="flex-1 shrink-0 flex items-center justify-end gap-x-2">
              <span class="text-sm text-gray-500 dark:text-gray-400">
                {role_name(guest_membership.role)}
              </span>
              <.button
                id={"guest-site-#{guest_membership.site.id}-leave"}
                theme="secondary"
                size="sm"
                phx-click="leave-site"
                phx-value-site-id={guest_membership.site.id}
                data-confirm={"Are you sure you want to leave #{guest_membership.site.domain}? You will lose access to its stats."}
              >
                Leave
              </.button>
            </div>
          </div>
        </div>
      </.tile>
    </.settings_tiles>
    """
  end

  def handle_event("leave-site", %{"site-id" => site_id}, socket) do
    %{current_user: user, guest_memberships: guest_memberships} = socket.assigns

    guest_membership = Enum.find(guest_memberships, &(to_string(&1.site_id) == site_id))

    socket =
      with %{site: site} <- guest_membership,
           {:ok, _} <- Teams.Memberships.remove(site, user, send_email?: false) do
        put_live_flash(socket, :success, "You have left #{site.domain}")
      else
        _ -> put_live_flash(socket, :error, "You're no longer a guest of this site")
      end

    {:noreply, load_guest_memberships(socket)}
  end

  defp load_guest_memberships(socket) do
    case Teams.Memberships.guest_memberships(socket.assigns.current_user) do
      [] ->
        socket
        |> assign(guest_memberships: [], has_guest_sites?: false)
        |> push_navigate(to: ~p"/settings/preferences")

      guest_memberships ->
        assign(socket, guest_memberships: guest_memberships, has_guest_sites?: true)
    end
  end

  defp owned_by(team) do
    if Teams.setup?(team) do
      Teams.name(team)
    else
      case team.owners do
        [owner | _] -> "Owned by #{owner.name}"
        [] -> ""
      end
    end
  end

  defp role_name(role), do: role |> to_string() |> String.capitalize()
end
