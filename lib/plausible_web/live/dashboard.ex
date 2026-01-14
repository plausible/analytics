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

  def mount(_params, %{"domain" => domain, "url" => url}, socket) do
    user_prefs = get_connect_params(socket)["user_prefs"] || %{}

    # As domain is passed via session, the associated site has already passed
    # validation logic on plug level.
    site =
      Plausible.Site
      |> Repo.get_by!(domain: domain)
      |> Repo.preload([
        :owners,
        :completed_imports,
        team: [:owners, subscription: Teams.last_subscription_query()]
      ])

    socket =
      socket
      |> assign(:connected?, connected?(socket))
      |> assign(:site, site)
      |> assign(:user_prefs, user_prefs)

    {:noreply, socket} = handle_params_internal(%{}, url, socket)

    {:ok, socket}
  end

  def handle_params_internal(_params, url, socket) do
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
    <div id="live-dashboard-container" phx-hook="DashboardRoot">
      <.portal_wrapper id="pages-breakdown-live-container" target="#pages-breakdown-live">
        <.live_component
          module={PlausibleWeb.Live.Dashboard.Pages}
          id="pages-breakdown-component"
          site={@site}
          user_prefs={@user_prefs}
          connected?={@connected?}
          params={@params}
        />
      </.portal_wrapper>
    </div>
    """
  end

  def handle_event("handle_dashboard_params", %{"url" => url}, socket) do
    query =
      url
      |> URI.parse()
      |> Map.fetch!(:query)

    params = URI.decode_query(query || "")

    handle_params_internal(params, url, socket)
  end

  attr :id, :string, required: true
  attr :target, :string, required: true

  slot :inner_block

  if Mix.env() in [:test, :ce_test] do
    defp portal_wrapper(assigns) do
      ~H"""
      <div id={@id}>{render_slot(@inner_block)}</div>
      """
    end
  else
    defp portal_wrapper(assigns) do
      ~H"""
      <.portal id={@id} target={@target}>{render_slot(@inner_block)}</.portal>
      """
    end
  end
end
