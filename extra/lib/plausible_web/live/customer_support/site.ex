defmodule PlausibleWeb.Live.CustomerSupport.Site do
  @moduledoc """
  Site coordinator LiveView for Customer Support interface.

  Manages tab-based navigation and delegates rendering to specialized 
  components: Overview, People, and Rescue Zone.
  """
  use PlausibleWeb.CustomerSupport.Live

  alias PlausibleWeb.CustomerSupport.Site.Components.{
    Overview,
    People,
    RescueZone
  }

  def favicon(assigns) do
    ~H"""
    <img src={"/favicon/sources/#{@domain}"} class={@class} />
    """
  end

  def handle_params(%{"id" => site_id} = params, _uri, socket) do
    tab = params["tab"] || "overview"
    site = Resource.Site.get(site_id)

    if site do
      socket =
        socket
        |> assign(:site, site)
        |> assign(:tab, tab)

      {:noreply, handle_tab_change_for(socket, tab, params, :site, &tab_component/1)}
    else
      {:noreply, redirect(socket, to: Routes.customer_support_path(socket, :index))}
    end
  end

  def render(assigns) do
    ~H"""
    <Layout.layout show_search={false} flash={@flash}>
      <.site_header site={@site} />
      <.site_tab_navigation site={@site} tab={@tab} />

      <.live_component
        module={tab_component(@tab)}
        site={@site}
        tab={@tab}
        id={"site-#{@site.id}-#{@tab}"}
      />
    </Layout.layout>
    """
  end

  defp site_header(assigns) do
    ~H"""
    <div class="flex items-center">
      <div class="rounded-full p-1 mr-4">
        <.favicon class="w-8" domain={@site.domain} />
      </div>
      <div>
        <p class="text-xl font-bold sm:text-2xl">
          {@site.domain}
          <span
            :if={
              @site.ingest_rate_limit_threshold &&
                @site.ingest_rate_limit_threshold < @site.ingest_rate_limit_scale_seconds
            }
            class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-red-100 text-red-800"
          >
            Rejecting traffic
          </span>

          <span
            :if={@site.ingest_rate_limit_threshold == 0}
            class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-red-100 text-red-800"
          >
            Traffic blocked
          </span>
        </p>
        <p class="text-sm font-medium">
          Timezone: {@site.timezone}
        </p>
        <p class="text-sm font-medium">
          Team:
          <.styled_link patch={
            Routes.customer_support_team_path(PlausibleWeb.Endpoint, :show, @site.team.id)
          }>
            {@site.team.name}
          </.styled_link>
        </p>
        <p class="text-sm font-medium">
          <span :if={@site.domain_changed_from}>(previously: {@site.domain_changed_from})</span>
        </p>
      </div>
    </div>
    """
  end

  defp site_tab_navigation(assigns) do
    ~H"""
    <.tab_navigation tab={@tab}>
      <:tabs>
        <.tab to="overview" tab={@tab}>Overview</.tab>
        <.tab to="people" tab={@tab}>People</.tab>
        <.tab to="rescue-zone" tab={@tab}>Rescue Zone</.tab>
      </:tabs>
    </.tab_navigation>
    """
  end

  defp tab_component("overview"), do: Overview
  defp tab_component("people"), do: People
  defp tab_component("rescue-zone"), do: RescueZone
  defp tab_component(_), do: Overview
end
