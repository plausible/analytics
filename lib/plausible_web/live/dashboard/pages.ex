defmodule PlausibleWeb.Live.Dashboard.Pages do
  @moduledoc """
  Pages breakdown component.
  """

  use PlausibleWeb, :live_component

  alias PlausibleWeb.Components.Dashboard.ReportList
  alias PlausibleWeb.Components.Dashboard.Tile

  alias Plausible.Stats
  alias Plausible.Stats.{ParsedQueryParams, QueryBuilder, QueryResult}

  @tabs [
    {"pages", "Top Pages"},
    {"entry-pages", "Entry Pages"},
    {"exit-pages", "Exit Pages"}
  ]

  @key_labels %{
    "pages" => "Page",
    "entry-pages" => "Entry page",
    "exit-pages" => "Exit page"
  }

  @pagination %{limit: 9, offset: 0}

  @filter_dimensions %{
    "pages" => "event:page",
    "entry-pages" => "visit:entry_page",
    "exit-pages" => "visit:exit_page"
  }

  def update(assigns, socket) do
    active_tab = assigns.user_prefs["pages_tab"] || "pages"

    socket =
      assign(socket,
        site: assigns.site,
        params: assigns.params,
        tabs: @tabs,
        key_labels: @key_labels,
        filter_dimensions: @filter_dimensions,
        active_tab: active_tab,
        connected?: assigns.connected?
      )
      |> load_stats()

    {:ok, socket}
  end

  def render(assigns) do
    assigns = assign(assigns, :external_link_fn, &external_link/1)

    ~H"""
    <div>
      <Tile.tile
        id="breakdown-tile-pages"
        class="group/report"
        title={@key_labels[@active_tab]}
        connected?={@connected?}
        target={@myself}
        height={ReportList.height()}
      >
        <:tabs>
          <Tile.tab
            :for={{value, label} <- @tabs}
            label={label}
            value={value}
            active={@active_tab}
            target={@myself}
          />
        </:tabs>

        <ReportList.report
          site={@site}
          data_test_id={"#{@active_tab}-report-list"}
          key_label={@key_labels[@active_tab]}
          filter_dimension={@filter_dimensions[@active_tab]}
          params={@params}
          query_result={@query_result}
          external_link_fn={@external_link_fn}
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

  defp external_link(_item) do
    "https://example.com"
  end

  defp load_stats(socket) do
    %{active_tab: active_tab, site: site, params: params} = socket.assigns

    assign_async(socket, :query_result, fn ->
      metrics = choose_metrics(params)
      dimension = @filter_dimensions[active_tab]

      params =
        params
        |> ParsedQueryParams.set(
          metrics: metrics,
          dimensions: [dimension],
          pagination: @pagination
        )

      query = QueryBuilder.build!(site, params)

      %QueryResult{} = query_result = Stats.query(site, query)

      {:ok, %{query_result: query_result}}
    end)
  end

  defp choose_metrics(%ParsedQueryParams{} = params) do
    if ParsedQueryParams.conversion_goal_filter?(params) do
      [:visitors, :conversion_rate]
    else
      [:visitors]
    end
  end
end
