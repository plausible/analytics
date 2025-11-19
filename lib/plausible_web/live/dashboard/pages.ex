defmodule PlausibleWeb.Live.Dashboard.Pages do
  @moduledoc """
  LV version of pages breakdown.
  """

  use PlausibleWeb, :live_view

  alias Plausible.Stats
  alias Plausible.Stats.Filters
  alias Plausible.Stats.Query

  @max_items 9
  @min_height 380
  @row_height 32
  @row_gap_height 4
  @data_container_height (@row_height + @row_gap_height) * (@max_items - 1) + @row_height
  @col_min_width 70

  @metrics %{
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
  }

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       max_items: @max_items,
       min_height: @min_height,
       row_height: @row_height,
       row_gap_height: @row_gap_height,
       data_container_height: @data_container_height,
       col_min_width: @col_min_width
     )}
  end

  def handle_params(%{"domain" => domain} = params, _uri, socket) do
    site = Plausible.Sites.get_for_user(socket.assigns.current_user, domain)

    params = Map.put(params, "property", "event:page")
    query = Query.from(site, params, %{})

    metrics = breakdown_metrics(query)
    pagination = parse_pagination(params)

    %{results: results, meta: meta} = Stats.breakdown(site, query, metrics, pagination)

    pages =
      results
      |> transform_keys(%{page: :name})

    socket =
      assign(
        socket,
        metrics: Enum.map(metrics, &Map.fetch!(@metrics, &1)),
        results: Enum.take(pages, @max_items),
        meta: Map.merge(meta, Stats.Breakdown.formatted_date_ranges(query)),
        skip_imported_reason: meta[:imports_skip_reason]
      )

    {:noreply, socket}
  end

  def render(assigns) do
    tabs = [
      %{label: "Top Pages", value: "pages", active: true},
      %{label: "Entry Pages", value: "entry-pages", active: false},
      %{label: "Exit Pages", value: "exit-pages", active: false}
    ]

    assigns = assign(assigns, :tabs, tabs)

    ~H"""
    <div>
      <div class="w-full flex justify-between h-full">
        <div class="flex gap-x-1">
          <h3 class="font-bold dark:text-gray-100">
            Top Pages
          </h3>
        </div>

        <div class="flex text-xs font-medium text-gray-500 dark:text-gray-400 space-x-2 items-baseline">
          <button
            :for={tab <- @tabs}
            class="rounded-sm truncate text-left transition-colors duration-150"
          >
            <span class={
              if(tab.active,
                do:
                  "text-indigo-600 dark:text-indigo-500 font-bold underline decoration-2 decoration-indigo-600 dark:decoration-indigo-500",
                else: "hover:text-indigo-700 dark:hover:text-indigo-400 cursor-pointer"
              )
            }>
              {tab.label}
            </span>
          </button>
        </div>
      </div>

      <div
        :if={Enum.empty?(@results)}
        class="w-full h-full flex flex-col justify-center"
        style={"min-height: #{@min_height}px;"}
      >
        <div class="mx-auto font-medium text-gray-500 dark:text-gray-400">
          No data yet
        </div>
      </div>

      <div class="w-full" style={"min-height: #{@min_height}px;"}>
        <div class="h-full flex flex-col">
          <div style={"height: #{@row_height}px"}>
            <div class="pt-3 w-full text-xs font-bold tracking-wide text-gray-500 flex items-center dark:text-gray-400">
              <span class="grow truncate">Page</span>
              <div
                :for={metric <- @metrics}
                class={[metric.key, "text-right"]}
                style={"min-width: #{@col_min_width};"}
              >
                {metric.label}
              </div>
            </div>
          </div>

          <div class="grow" style={"min-height: #{@data_container_height}px;"}>
            <div :for={{item, idx} <- Enum.with_index(@results)} style={"min-height: #{@row_height}px;"}>
              <div class="flex w-full items-center" style={"margin-top: #{@row_gap_height}"}>
                <div class="grow w-full overflow-hidden">
                  <div class="flex justify-start px-2 py-1.5 group text-sm dark:text-gray-300 relative z-9 break-all w-full">
                    <span class="w-full md:truncate">
                      <a
                        id={"filter-link-#{idx}"}
                        phx-hook="LiveDashboard"
                        data-widget="patch-filters-button"
                        data-filter={Jason.encode!(%{prefix: "page", filter: ["is", "page", [item.name]]})}
                        href="#">
                        {trim_name(item.name, @col_min_width)}
                      </a>
                    </span>
                  </div>
                </div>
                <div
                  :for={metric <- @metrics}
                  class="text-right"
                  style={"width: #{@col_min_width}; min-width: #{@col_min_width};"}
                >
                  <span class="font-medium text-sm dark:text-gray-200 text-right">
                    {item[metric.key]}
                  </span>
                </div>
              </div>
            </div>
          </div>

          <div class="w-full text-center">
            <a
              id="modal-link"
              phx-hook="LiveDashboard"
              data-widget="modal-button"
              data-modal="pages"
              href="#"
              class="leading-snug font-bold text-sm text-gray-500 dark:text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 transition-colors duration-150 tracking-wide"
            >
              <svg
                class="feather mr-1"
                style="margin-top: -2px;"
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
              >
                <path d="M8 3H5a2 2 0 0 0-2 2v3m18 0V5a2 2 0 0 0-2-2h-3m0 18h3a2 2 0 0 0 2-2v-3M3 16v3a2 2 0 0 0 2 2h3" />
              </svg>
              DETAILS
            </a>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp trim_name(name, max_length) do
    if String.length(name) <= max_length do
      name
    else
      left_length = div(max_length, 2)
      right_length = max_length - left_length

      left_side = String.slice(name, 0..left_length)
      right_side = String.slice(name, -right_length..-1)

      left_side <> "..." <> right_side
    end
  end

  defp parse_pagination(params) do
    limit = to_int(params["limit"], 9)
    page = to_int(params["page"], 1)
    {limit, page}
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

  defp to_int(string, default) when is_binary(string) do
    case Integer.parse(string) do
      {i, ""} when is_integer(i) ->
        i

      _ ->
        default
    end
  end

  defp to_int(_, default), do: default

  defp toplevel_goal_filter?(query) do
    Filters.filtering_on_dimension?(query, "event:goal",
      max_depth: 0,
      behavioral_filters: :ignore
    )
  end
end
