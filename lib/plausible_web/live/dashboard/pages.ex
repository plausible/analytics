defmodule PlausibleWeb.Live.Dashboard.Pages do
  @moduledoc """
  Pages breakdown component.
  """

  use PlausibleWeb, :live_component

  alias PlausibleWeb.Components.Dashboard.ReportList
  alias PlausibleWeb.Components.Dashboard.Tile

  alias Plausible.Stats
  alias Plausible.Stats.Filters

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

  @max_items 9
  @pagination_params {@max_items, 1}

  @metrics %{
    "pages" => %{
      visitors: %{
        width: "w-24",
        key: :visitors,
        label: "Visitors",
        sortable: true,
        plot: true
      },
      conversion_rate: %{
        width: "w-24",
        key: :conversion_rate,
        label: "CR",
        sortable: true
      }
    },
    "entry-pages" => %{
      visitors: %{
        width: "w-24",
        key: :visitors,
        label: "Unique Entrances",
        sortable: true,
        plot: true
      },
      conversion_rate: %{
        width: "w-24",
        key: :conversion_rate,
        label: "CR",
        sortable: true
      }
    },
    "exit-pages" => %{
      visitors: %{
        width: "w-24",
        key: :visitors,
        label: "Unique Exits",
        sortable: true,
        plot: true
      },
      conversion_rate: %{
        width: "w-24",
        key: :conversion_rate,
        label: "CR",
        sortable: true
      }
    }
  }

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
        query: assigns.query,
        tabs: @tabs,
        key_labels: @key_labels,
        filter_dimensions: @filter_dimensions,
        active_tab: active_tab,
        connected?: assigns.connected?
      )
      |> load_metrics()

    {:ok, socket}
  end

  def render(assigns) do
    assigns = assign(assigns, :external_link_fn, &external_link/1)
    ~H"""
    <div>
      <Tile.tile id="breakdown-tile-pages" title={@key_labels[@active_tab]} connected?={@connected?}>
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
          key_label={@key_labels[@active_tab]}
          filter_dimension={@filter_dimensions[@active_tab]}
          params={@params}
          results={@results}
          meta={@meta}
          metrics={@metrics}
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
        |> load_metrics()

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  defp external_link(_item) do
    "https://example.com"
  end

  defp load_metrics(socket) do
    %{results: pages, meta: meta, metrics: metrics} =
      metrics_for_tab(socket.assigns.active_tab, socket.assigns.site, socket.assigns.query)

    assign(
      socket,
      metrics: Enum.map(metrics, &Map.fetch!(@metrics[socket.assigns.active_tab], &1)),
      results: Enum.take(pages, @max_items),
      meta: Map.merge(meta, Stats.Breakdown.formatted_date_ranges(socket.assigns.query)),
      skip_imported_reason: meta[:imports_skip_reason]
    )
  end

  defp metrics_for_tab("pages", site, query) do
    query = struct!(query, dimensions: ["event:page"])

    metrics = breakdown_metrics(query)

    %{results: results, meta: meta} = Stats.breakdown(site, query, metrics, @pagination_params)

    pages =
      results
      |> transform_keys(%{page: :name})

    %{results: pages, meta: meta, metrics: metrics}
  end

  defp metrics_for_tab("entry-pages", site, query) do
    query = struct!(query, dimensions: ["visit:entry_page"])

    metrics = breakdown_metrics(query)

    %{results: results, meta: meta} = Stats.breakdown(site, query, metrics, @pagination_params)

    pages =
      results
      |> transform_keys(%{entry_page: :name})

    %{results: pages, meta: meta, metrics: metrics}
  end

  defp metrics_for_tab("exit-pages", site, query) do
    query = struct!(query, dimensions: ["visit:exit_page"])

    metrics = breakdown_metrics(query)

    %{results: results, meta: meta} = Stats.breakdown(site, query, metrics, @pagination_params)

    pages =
      results
      |> transform_keys(%{exit_page: :name})

    %{results: pages, meta: meta, metrics: metrics}
  end

  defp breakdown_metrics(query) do
    if toplevel_goal_filter?(query) do
      [:visitors, :conversion_rate]
    else
      [:visitors]
    end
  end

  defp transform_keys(result, keys_to_replace) when is_map(result) do
    for {key, val} <- result, do: {Map.get(keys_to_replace, key, key), val}, into: %{}
  end

  defp transform_keys(results, keys_to_replace) when is_list(results) do
    Enum.map(results, &transform_keys(&1, keys_to_replace))
  end

  defp toplevel_goal_filter?(query) do
    Filters.filtering_on_dimension?(query, "event:goal",
      max_depth: 0,
      behavioral_filters: :ignore
    )
  end
end
