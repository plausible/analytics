defmodule PlausibleWeb.Live.Dashboard do
  @moduledoc """
  LiveView for site dashboard.
  """

  use PlausibleWeb, :live_view

  alias Plausible.Repo
  alias Plausible.Stats.{Dashboard, ParsedQueryParams}
  alias Plausible.Teams

  @realtime_refresh_interval :timer.seconds(3)

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
    current_path = socket.assigns[:path] || []
    path = uri.path |> String.split("/") |> Enum.drop(2)
    uri_query = uri.query || ""

    socket =
      if uri_query != socket.assigns[:uri_query] do
        {:ok, params} =
          Dashboard.QueryParser.parse(
            uri_query,
            socket.assigns.site,
            socket.assigns.user_prefs
          )

        assign(socket, params: params, uri_query: uri_query)
      else
        socket
      end

    socket =
      socket
      |> assign(last_realtime_update: nil)
      |> assign(:path, path)
      |> assign_new(:initial_path, fn -> path end)
      |> maybe_close_modal(current_path)
      |> maybe_cancel_existing_realtime_timer()
      |> maybe_assign_realtime_timer()

    {:noreply, socket}
  end

  def handle_info(:refresh_realtime_stats, socket) do
    now = System.monotonic_time(:second)
    socket = assign(socket, :last_realtime_update, now)
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
        last_realtime_update={@last_realtime_update}
        site={@site}
        user_prefs={@user_prefs}
        connected?={@connected?}
        params={@params}
      />
      <.live_component
        module={PlausibleWeb.Live.Dashboard.Pages}
        id="pages-breakdown-component"
        last_realtime_update={@last_realtime_update}
        site={@site}
        user_prefs={@user_prefs}
        connected?={@connected?}
        params={@params}
      />
      <.live_component
        module={PlausibleWeb.Live.Dashboard.DetailsModal}
        id="pages-breakdown-details-component"
        key="pages"
        key_label="Page"
        title="Top Pages"
        dimension="event:page"
        site={@site}
        user_prefs={@user_prefs}
        connected?={@connected?}
        params={@params}
        open?={@initial_path == ["pages"]}
      />
      <.live_component
        module={PlausibleWeb.Live.Dashboard.DetailsModal}
        id="entry-pages-breakdown-details-component"
        key="entry-pages"
        key_label="Entry Page"
        title="Entry Pages"
        dimension="visit:entry_page"
        site={@site}
        user_prefs={@user_prefs}
        connected?={@connected?}
        params={@params}
        open?={@initial_path == ["entry-pages"]}
      />
      <.live_component
        module={PlausibleWeb.Live.Dashboard.DetailsModal}
        id="exit-pages-breakdown-details-component"
        key="exit-pages"
        key_label="Exit Page"
        title="Exit Pages"
        dimension="visit:exit_page"
        site={@site}
        user_prefs={@user_prefs}
        connected?={@connected?}
        params={@params}
        open?={@initial_path == ["exit-pages"]}
      />
      <.live_component
        module={PlausibleWeb.Live.Dashboard.DetailsModal}
        id="sources-breakdown-details-component"
        key="sources"
        key_label="Source"
        title="Sources"
        dimension="visit:source"
        site={@site}
        user_prefs={@user_prefs}
        connected?={@connected?}
        params={@params}
        open?={@initial_path == ["sources"]}
      />
      <.live_component
        module={PlausibleWeb.Live.Dashboard.DetailsModal}
        id="channels-breakdown-details-component"
        key="channels"
        key_label="Channel"
        title="Channels"
        dimension="visit:channel"
        site={@site}
        user_prefs={@user_prefs}
        connected?={@connected?}
        params={@params}
        open?={@initial_path == ["channels"]}
      />
      <.live_component
        module={PlausibleWeb.Live.Dashboard.DetailsModal}
        id="utm-mediums-breakdown-details-component"
        key="utm-mediums"
        key_label="Medium"
        title="UTM mediums"
        dimension="visit:utm_medium"
        site={@site}
        user_prefs={@user_prefs}
        connected?={@connected?}
        params={@params}
        open?={@initial_path == ["utm_medium"]}
      />
    </div>
    """
  end

  @modals %{
    ["pages"] => "pages-breakdown-details-modal",
    ["entry-pages"] => "entry-pages-breakdown-details-modal",
    ["exit-pages"] => "exit-pages-breakdown-details-modal",
    ["sources"] => "sources-breakdown-details-modal",
    ["channels"] => "channels-breakdown-details-modal",
    ["utm_medium"] => "utm-mediums-breakdown-details-modal"
  }

  defp maybe_close_modal(socket, old_path) do
    if length(old_path) == 1 and socket.assigns.path == [] and Map.has_key?(@modals, old_path) do
      Prima.Modal.push_close(socket, @modals[old_path])
    else
      socket
    end
  end

  defp maybe_cancel_existing_realtime_timer(socket) do
    case socket.assigns[:realtime_timer_ref] do
      nil ->
        socket

      timer_ref ->
        :timer.cancel(timer_ref)
        assign(socket, realtime_timer_ref: nil)
    end
  end

  defp maybe_assign_realtime_timer(socket) do
    case socket.assigns[:params] do
      %ParsedQueryParams{input_date_range: :realtime} ->
        {:ok, timer_ref} =
          :timer.send_interval(@realtime_refresh_interval, self(), :refresh_realtime_stats)

        assign(socket,
          realtime_timer_ref: timer_ref,
          last_realtime_update: System.monotonic_time(:second)
        )

      _ ->
        socket
    end
  end
end
