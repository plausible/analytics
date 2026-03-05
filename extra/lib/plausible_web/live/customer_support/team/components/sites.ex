defmodule PlausibleWeb.CustomerSupport.Team.Components.Sites do
  @moduledoc """
  Team sites component - handles team sites listing
  """
  use PlausibleWeb, :live_component

  import Ecto.Query, except: [update: 2, update: 3]
  import PlausibleWeb.Live.Components.Pagination

  alias Plausible.Repo
  alias Plausible.Site
  alias Plausible.Sites.Index

  @page_size 24

  def update(%{team: team, tab_params: tab_params}, socket) do
    team = Repo.preload(team, :owners)
    owner = List.first(team.owners)

    socket =
      assign_new(socket, :index_state, fn ->
        Index.build(owner, team: team, sort_by: :traffic, sort_direction: :desc)
      end)

    page = Index.paginate(socket.assigns.index_state, tab_params["page"], @page_size)

    sites = fetch_sites(page.entries)

    hourly_stats = build_hourly_stats(sites, socket)

    uri =
      Routes.customer_support_team_path(PlausibleWeb.Endpoint, :show, team.id, tab: "sites")
      |> URI.parse()

    {:ok,
     assign(socket,
       team: team,
       sites: sites,
       hourly_stats: hourly_stats,
       page_number: page.page_number,
       total_pages: page.total_pages,
       total_entries: page.total_entries,
       uri: uri
     )}
  end

  def update(%{team: team}, socket) do
    update(%{team: team, tab_params: %{}}, socket)
  end

  def handle_event("sort", %{"by" => by}, socket) do
    sort_by = parse_sort_by(by)
    current_state = socket.assigns.index_state
    current_sort_by = current_state.sort_by

    sort_direction =
      case sort_by do
        ^current_sort_by ->
          flip_direction(current_state.sort_direction)

        :traffic ->
          :desc

        :alnum ->
          :asc
      end

    new_state = Index.sort(current_state, sort_by: sort_by, sort_direction: sort_direction)
    page = Index.paginate(new_state, 1, @page_size)
    sites = fetch_sites(page.entries)

    hourly_stats = build_hourly_stats(sites, socket)

    {:noreply,
     assign(socket,
       index_state: new_state,
       sites: sites,
       page_number: page.page_number,
       total_pages: page.total_pages,
       total_entries: page.total_entries,
       hourly_stats: hourly_stats
     )}
  end

  def render(assigns) do
    assigns =
      assign(assigns,
        sort_by: assigns.index_state.sort_by,
        sort_direction: assigns.index_state.sort_direction
      )

    ~H"""
    <div class="mt-2">
      <.table rows={@sites}>
        <:thead>
          <th
            scope="col"
            class="px-6 first:pl-0 last:pr-0 py-3 text-left text-sm font-semibold cursor-pointer select-none"
            phx-click="sort"
            phx-value-by="alnum"
            phx-target={@myself}
          >
            Domain <.sort_arrow active={@sort_by == :alnum} direction={@sort_direction} />
          </th>
          <.th>Previous Domain</.th>
          <.th>Timezone</.th>
          <.th invisible>Settings</.th>
          <.th invisible>Dashboard</.th>
          <th
            scope="col"
            class="max-w-40 px-6 first:pl-0 last:pr-0 py-3 text-left text-sm font-semibold cursor-pointer select-none"
            phx-click="sort"
            phx-value-by="traffic"
            phx-target={@myself}
          >
            Traffic <.sort_arrow active={@sort_by == :traffic} direction={@sort_direction} />
          </th>
        </:thead>
        <:tbody :let={site}>
          <.td>
            <div class="flex items-center">
              <img
                src="/favicon/sources/{site.domain}"
                onerror="this.onerror=null; this.src='/favicon/sources/placeholder';"
                class="w-4 h-4 flex-shrink-0 mt-px mr-2"
              />
              <.styled_link
                patch={Routes.customer_support_site_path(PlausibleWeb.Endpoint, :show, site.id)}
                class="cursor-pointer flex block items-center"
              >
                {site.domain}

                <span :if={@index_state.pins[site.id]}>
                  <PlausibleWeb.Components.Icons.pin_icon class="w-4 ml-2" />
                </span>
              </.styled_link>
            </div>
          </.td>
          <.td>{site.domain_changed_from || "--"}</.td>
          <.td>{site.timezone}</.td>
          <.td>
            <.styled_link
              new_tab={true}
              href={Routes.stats_path(PlausibleWeb.Endpoint, :stats, site.domain, [])}
            >
              Dashboard
            </.styled_link>
          </.td>
          <.td>
            <.styled_link
              new_tab={true}
              href={Routes.site_path(PlausibleWeb.Endpoint, :settings_general, site.domain, [])}
            >
              Settings
            </.styled_link>
          </.td>
          <.td max_width="max-w-40">
            <span class="h-[24px] text-indigo-500">
              <PlausibleWeb.Live.Components.Visitors.chart
                :if={is_map(@hourly_stats[site.domain])}
                intervals={@hourly_stats[site.domain].intervals}
                height={20}
              />
            </span>
            <span class="text-[10px]">
              Unique visitors: {if is_map(@hourly_stats),
                do: @hourly_stats[site.domain][:visitors] || 0,
                else: 0}
            </span>
          </.td>
        </:tbody>
      </.table>
      <.pagination
        :if={@total_pages > 1}
        id="sites-pagination"
        uri={@uri}
        page_number={@page_number}
        total_pages={@total_pages}
      >
        Total of <span class="font-medium">{@total_entries}</span>
        sites. Page {@page_number} of {@total_pages}
      </.pagination>
    </div>
    """
  end

  defp fetch_sites([]), do: []

  defp fetch_sites(site_ids) do
    by_id =
      from(s in Site.regular(),
        where: s.id in ^site_ids,
        select: {s.id, s}
      )
      |> Repo.all()
      |> Map.new()

    Enum.map(site_ids, fn id -> Map.get(by_id, id) end)
  end

  defp build_hourly_stats(sites, socket) do
    if connected?(socket) do
      Plausible.Stats.Sparkline.parallel_overview(sites)
    else
      sites
      |> Enum.map(fn site ->
        {site.domain,
         %{
           intervals: Plausible.Stats.Sparkline.empty_24h_intervals(),
           visitors: 0,
           visitors_change: 0
         }}
      end)
      |> Map.new()
    end
  end

  defp parse_sort_by("alnum"), do: :alnum
  defp parse_sort_by(_), do: :traffic

  defp flip_direction(:asc), do: :desc
  defp flip_direction(:desc), do: :asc

  attr :active, :boolean, required: true
  attr :direction, :atom, required: true

  defp sort_arrow(%{active: false} = assigns) do
    ~H"""
    <span class="opacity-30">↕</span>
    """
  end

  defp sort_arrow(%{direction: :asc} = assigns) do
    ~H"""
    <span>↑</span>
    """
  end

  defp sort_arrow(assigns) do
    ~H"""
    <span>↓</span>
    """
  end
end
