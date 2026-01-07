defmodule PlausibleWeb.Live.Dashboard.Pages do
  @moduledoc """
  Pages breakdown component.
  """

  use PlausibleWeb, :live_component

  alias PlausibleWeb.Components.Dashboard.{ReportList, Tile, ImportedDataWarnings}

  alias Plausible.Stats
  alias Plausible.Stats.{ParsedQueryParams, QueryBuilder, QueryResult}

  import Plausible.Stats.Dashboard.Utils

  @tabs [
    %{
      tab_key: "pages",
      report_label: "Top pages",
      key_label: "Page",
      dimension: "event:page"
    },
    %{
      tab_key: "entry-pages",
      report_label: "Entry pages",
      key_label: "Entry page",
      dimension: "visit:entry_page"
    },
    %{
      tab_key: "exit-pages",
      report_label: "Exit pages",
      key_label: "Exit page",
      dimension: "visit:exit_page"
    }
  ]

  @pagination %{limit: 9, offset: 0}

  def update(assigns, socket) do
    active_tab = assigns.user_prefs["pages_tab"] || "pages"

    socket =
      assign(socket,
        site: assigns.site,
        params: assigns.params,
        tabs: @tabs,
        active_tab: active_tab,
        connected?: assigns.connected?
      )
      |> load_stats()

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <Tile.tile
        id="breakdown-tile-pages"
        details_route={dashboard_route(@site, @params, path: "/#{@active_tab}")}
        title={get_tab_info(@active_tab, :report_label)}
        connected?={@connected?}
        target={@myself}
        height={ReportList.height()}
      >
        <:warnings>
          <ImportedDataWarnings.unsupported_filters query_result={@query_result} />
        </:warnings>
        <:tabs>
          <Tile.tab
            :for={%{tab_key: tab_key, report_label: report_label} <- @tabs}
            report_label={report_label}
            tab_key={tab_key}
            active_tab={@active_tab}
            target={@myself}
          />
        </:tabs>

        <ReportList.report
          site={@site}
          data_test_id={"#{@active_tab}-report-list"}
          key_label={get_tab_info(@active_tab, :key_label)}
          dimension={get_tab_info(@active_tab, :dimension)}
          params={@params}
          query_result={@query_result}
          external_link_fn={page_external_link_fn_for(@site)}
        />
      </Tile.tile>
    </div>
    """
  end

  def handle_event("set-tab", %{"tab" => tab}, socket) do
    if tab != socket.assigns.active_tab do
      socket =
        socket
        |> assign(:active_tab, tab)
        |> load_stats()

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  defp load_stats(socket) do
    %{active_tab: active_tab, site: site, params: params} = socket.assigns

    metrics = choose_metrics(params)
    dimension = get_tab_info(active_tab, :dimension)

    params =
      params
      |> ParsedQueryParams.set(
        metrics: metrics,
        dimensions: [dimension],
        pagination: @pagination
      )

    query = QueryBuilder.build!(site, params)

    %QueryResult{} = query_result = Stats.query(site, query)

    assign(socket, :query_result, query_result)
  end

  defp choose_metrics(%ParsedQueryParams{} = params) do
    if ParsedQueryParams.conversion_goal_filter?(params) do
      [:visitors, :group_conversion_rate]
    else
      [:visitors]
    end
  end

  defp get_tab_info(tab_key, field) do
    @tabs
    |> Enum.find(&(&1.tab_key == tab_key))
    |> Map.fetch!(field)
  end
end
