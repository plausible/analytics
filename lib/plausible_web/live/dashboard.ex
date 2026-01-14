defmodule PlausibleWeb.Live.Dashboard do
  @moduledoc """
  LiveView for site dashboard.
  """

  use PlausibleWeb, :live_view

  alias Plausible.Repo
  alias Plausible.Stats.Dashboard
  alias Plausible.Teams

  @spec enabled?(Plausible.Site.t() | nil) :: boolean()
  def enabled?(nil), do: false

  def enabled?(site) do
    FunWithFlags.enabled?(:live_dashboard, for: site)
  end

  def mount(%{"domain" => domain} = _params, _session, socket) do
    site =
      Plausible.Sites.get_for_user!(socket.assigns.current_user, domain,
        roles: [
          :owner,
          :admin,
          :editor,
          :super_admin,
          :viewer
        ]
      )
      |> Repo.preload([
        :owners,
        :completed_imports,
        team: [:owners, subscription: Teams.last_subscription_query()]
      ])

    user_prefs = get_connect_params(socket)["user_prefs"] || %{}

    socket =
      socket
      |> assign(:connected?, connected?(socket))
      |> assign(:site, site)
      |> assign(:user_prefs, user_prefs)

    {:ok, socket}
  end

  def handle_params(_params, url, socket) do
    uri = URI.parse(url)
    path = uri.path |> String.split("/") |> Enum.drop(2)

    {:ok, params} =
      Dashboard.QueryParser.parse(
        uri.query || "",
        socket.assigns.site,
        socket.assigns.user_prefs
      )

    socket =
      assign(socket,
        path: path,
        params: params
      )

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div
      id="live-dashboard-container"
      phx-hook="DashboardRoot"
      class="group/dashboard container print:max-w-full pt-6 mb-16 grid grid-cols-1 md:grid-cols-2 gap-5"
    >
      <div class="col-span-full flex items-center justify-end">
        <div :if={@connected?} class="flex shrink-0">
          <.live_component
            module={PlausibleWeb.Live.Dashboard.DatePicker}
            id="datepicker-component"
            site={@site}
            user_prefs={@user_prefs}
            connected?={@connected?}
            params={@params}
          />
        </div>
        <div :if={!@connected?} class="h-9 w-36 md:w-48 flex items-center shrink-0">
          <div class="h-3.5 w-full bg-gray-200 dark:bg-gray-700 rounded-full animate-pulse"></div>
        </div>
      </div>
      <.live_component
        module={PlausibleWeb.Live.Dashboard.Sources}
        id="sources-breakdown-component"
        site={@site}
        user_prefs={@user_prefs}
        connected?={@connected?}
        params={@params}
      />
      <.live_component
        module={PlausibleWeb.Live.Dashboard.Pages}
        id="pages-breakdown-component"
        site={@site}
        user_prefs={@user_prefs}
        connected?={@connected?}
        params={@params}
      />
      <.live_component
        module={PlausibleWeb.Live.Dashboard.PagesDetails}
        id="pages-breakdown-details-component"
        site={@site}
        user_prefs={@user_prefs}
        connected?={@connected?}
        params={@params}
        open?={@path == ["pages"]}
      />
    </div>
    """
  end
end
