defmodule PlausibleWeb.Live.Dashboard do
  @moduledoc """
  LiveView for site dashboard.
  """

  use PlausibleWeb, :live_view

  alias Plausible.Repo
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
      Repo.get_by!(Plausible.Site, domain: domain)
      |> Repo.preload([
        :owners,
        :completed_imports,
        team: [:owners, subscription: Teams.last_subscription_query()]
      ])

    socket =
      socket
      |> assign(:site, site)
      |> assign(:user_prefs, user_prefs)
      |> assign(:params, %{})

    {:noreply, socket} = handle_params_internal(%{}, url, socket)

    {:ok, socket}
  end

  def handle_params_internal(_params, _url, socket) do
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div id="live-dashboard-container"></div>
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
end
