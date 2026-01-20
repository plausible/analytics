defmodule PlausibleWeb.Components.Dashboard.ReportList do
  @moduledoc """
  ReportList component.
  """

  use PlausibleWeb, :component

  alias PlausibleWeb.Components.Dashboard.{Base, Metric}
  alias Plausible.Stats.{QueryResult, ParsedQueryParams}
  alias Plausible.Stats.Dashboard.Utils

  @max_items 9
  @min_height 356
  @row_height 32
  @row_gap_height 4
  @data_container_height (@row_height + @row_gap_height) * (@max_items - 1) + @row_height
  @col_min_width 70

  def height, do: @min_height

  attr :site, Plausible.Site, required: true
  attr :id, :string, required: true
  attr :params, ParsedQueryParams, required: true
  attr :connected?, :boolean, required: true
  attr :dimension, :string, required: true
  attr :key_label, :string, required: true
  attr :query_result, QueryResult, required: true
  attr :external_link_fn, :any, default: nil

  def report(assigns) do
    assigns =
      assign(assigns,
        max_items: @max_items,
        min_height: @min_height,
        row_height: @row_height,
        row_gap_height: @row_gap_height,
        data_container_height: @data_container_height,
        col_min_width: @col_min_width
      )

    if !assigns.connected? do
      ~H"""
      <.skeleton
        id={"#{@id}-skeleton"}
        min_height={@min_height}
        row_height={@row_height}
        row_gap_height={@row_gap_height}
        data_container_height={@data_container_height}
        col_min_width={@col_min_width}
        max_items={@max_items}
      />
      """
    else
      %QueryResult{results: results, meta: meta, query: query} = assigns.query_result

      assigns =
        assign(assigns,
          results: results,
          metric_keys: query[:metrics],
          metric_labels: meta[:metric_labels],
          empty?: Enum.empty?(results)
        )

      ~H"""
      <.skeleton
        :if={@empty?}
        id={"#{@id}-skeleton-loading"}
        min_height={@min_height}
        row_height={@row_height}
        row_gap_height={@row_gap_height}
        data_container_height={@data_container_height}
        col_min_width={@col_min_width}
        max_items={@max_items}
        class="hidden group-has-[.tile-tabs.phx-hook-loading]/report:block group-[.phx-navigation-loading]/dashboard:block"
      />

      <.no_data :if={@empty?} min_height={@min_height} id={"#{@id}-no-data"} />

      <div
        :if={not @empty?}
        id={@id}
        class="h-full flex flex-col group-has-[.tile-tabs.phx-hook-loading]/report:opacity-60 group-[.phx-navigation-loading]/dashboard:opacity-60"
      >
        <div
          class="group-has-[.tile-tabs.phx-hook-loading]/report:animate-pulse group-[.phx-navigation-loading]/dashboard:animate-pulse"
          style={"min-height: #{@row_height}px;"}
        >
          <.report_header
            key_label={@key_label}
            metric_labels={@metric_labels}
            col_min_width={@col_min_width}
          />
        </div>

        <div
          class="grow group-has-[.tile-tabs.phx-hook-loading]/report:animate-pulse group-[.phx-navigation-loading]/dashboard:animate-pulse"
          style={"min-height: #{@data_container_height}px;"}
        >
          <.report_row
            :for={{item, item_index} <- Enum.with_index(@results)}
            link_fn={assigns[:external_link_fn]}
            item={item}
            item_index={item_index}
            item_name={List.first(item.dimensions)}
            metrics={Enum.zip(@metric_keys, item.metrics)}
            bar_max_value={bar_max_value(@results, @metric_keys)}
            site={@site}
            params={@params}
            dimension={@dimension}
            row_height={@row_height}
            row_gap_height={@row_gap_height}
            col_min_width={@col_min_width}
          />
        </div>
      </div>
      """
    end
  end

  defp skeleton(assigns) do
    assigns =
      assigns
      |> assign(:bar_widths, [100, 45, 25, 14, 10, 7, 5, 4, 3])
      |> assign(:number_widths, [9, 8, 7, 8, 9, 7, 9, 7, 8])
      |> assign(:value_widths, [22, 16, 20, 14, 19, 15, 21, 13, 17])
      |> assign(:class, assigns[:class] || "")

    ~H"""
    <div
      id={@id}
      class={["h-full flex flex-col", @class]}
      style={"min-height: #{@min_height}px;"}
    >
      <div
        class="flex justify-between w-full pt-4"
        style={"height: #{@row_height}px;"}
      >
        <div class="w-12 h-2.5 bg-gray-200 dark:bg-gray-700 rounded-full animate-pulse"></div>
      </div>
      <div
        :for={
          {bar_width, number_width, value_width} <-
            Enum.zip([@bar_widths, @number_widths, @value_widths])
        }
        class="flex items-center justify-between w-full"
        style={"margin-top: #{@row_gap_height}px;"}
      >
        <div
          class="bg-gray-100/70 dark:bg-gray-800/70 rounded-sm animate-pulse relative"
          style={"height: #{@row_height}px; width: #{bar_width}%;"}
        >
          <div
            class="h-2.5 bg-gray-200 dark:bg-gray-700 rounded-full animate-pulse absolute top-1/2 -translate-y-1/2 left-2"
            style={"width: #{value_width * 4}px;"}
          >
          </div>
        </div>
        <div
          class="flex items-center justify-end"
          style={"height: #{@row_height}px; width: 70px;"}
        >
          <div
            class="h-2.5 bg-gray-200 dark:bg-gray-700 rounded-full animate-pulse"
            style={"width: #{number_width * 4}px;"}
          >
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp no_data(assigns) do
    ~H"""
    <div
      id={@id}
      class="w-full h-full flex flex-col justify-center group-has-[.tile-tabs.phx-hook-loading]/report:hidden group-[.phx-navigation-loading]/dashboard:hidden"
      style={"min-height: #{@min_height}px;"}
    >
      <div class="mx-auto text-sm font-medium text-gray-800 dark:text-gray-200">
        No data available
      </div>
    </div>
    """
  end

  defp external_link(assigns) do
    url = if(assigns[:link_fn], do: assigns.link_fn.(assigns.item))

    assigns = assign(assigns, :url, url)

    ~H"""
    <a
      :if={@url}
      target="_blank"
      rel="noreferrer"
      href={@url}
      class="invisible md:group-hover/row:visible"
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        fill="none"
        viewBox="0 0 24 24"
        class="inline size-3.5 mb-0.5 text-gray-600 dark:text-gray-400 hover:text-gray-800 dark:hover:text-gray-200"
      >
        <path
          stroke="currentColor"
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="2"
          d="M9 5H5a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-4M12 12l9-9-.303.303M14 3h7v7"
        />
      </svg>
    </a>
    """
  end

  defp report_header(assigns) do
    ~H"""
    <div class="pt-3 w-full text-xs font-medium text-gray-500 flex items-center dark:text-gray-400">
      <span data-test-id="report-list-0-0" class="grow truncate">{@key_label}</span>
      <div
        :for={{metric_label, index} <- Enum.with_index(@metric_labels)}
        class="text-right"
        style={"min-width: #{@col_min_width}px;"}
        data-test-id={"report-list-0-#{1 + index}"}
      >
        {metric_label}
      </div>
    </div>
    """
  end

  def report_row(assigns) do
    ~H"""
    <div style={"min-height: #{@row_height}px;"}>
      <div
        class="group/row flex w-full items-center hover:bg-gray-100/60 dark:hover:bg-gray-850 rounded-sm transition-colors duration-150"
        style={"margin-top: #{@row_gap_height}px;"}
      >
        <div class="grow w-full overflow-hidden" data-test-id={"report-list-#{1 + @item_index}-0"}>
          <Base.bar
            width={@metrics[:visitors]}
            max_width={@bar_max_value}
            background_class="bg-green-50 group-hover/row:bg-green-100 dark:bg-gray-500/15 dark:group-hover/row:bg-gray-500/30"
          >
            <div class="flex justify-start items-center gap-x-1.5 px-2 py-1.5 text-sm dark:text-gray-300 relative z-9 break-all w-full">
              <Base.dashboard_link
                class="block min-w-0 truncate hover:underline"
                to={Utils.dashboard_route(@site, @params, filter: [:is, @dimension, [@item_name]])}
              >
                {trim_name(@item_name, @col_min_width)}
              </Base.dashboard_link>
              <.external_link item={@item} link_fn={assigns[:link_fn]} />
            </div>
          </Base.bar>
        </div>
        <div
          :for={{{metric_key, metric_value}, metric_index} <- Enum.with_index(@metrics)}
          class="text-right"
          style={"width: #{@col_min_width}px; min-width: #{@col_min_width}px;"}
        >
          <span
            class="font-medium text-sm dark:text-gray-200 text-right"
            data-test-id={"report-list-#{1 + @item_index}-#{1 + metric_index}"}
          >
            <Metric.value name={metric_key} value={metric_value} />
          </span>
        </div>
      </div>
    </div>
    """
  end

  @bar_metric :visitors
  defp bar_max_value(results, metrics) do
    index = Enum.find_index(metrics, &(&1 == @bar_metric))

    results
    |> Enum.map(&Enum.at(&1.metrics, index))
    |> Enum.max(&>=/2, fn -> 0 end)
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
end
