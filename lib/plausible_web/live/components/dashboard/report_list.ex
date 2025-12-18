defmodule PlausibleWeb.Components.Dashboard.ReportList do
  @moduledoc """
  ReportList component.
  """

  use PlausibleWeb, :component

  alias PlausibleWeb.Components.Dashboard.Base
  alias PlausibleWeb.Components.Dashboard.Metric

  @max_items 9
  @min_height 380
  @row_height 32
  @row_gap_height 4
  @data_container_height (@row_height + @row_gap_height) * (@max_items - 1) + @row_height
  @col_min_width 70

  def height, do: @min_height

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

    if assigns.results.loading || !assigns.results.ok? do
      ~H"""
      """
    else
      results = assigns.results.result
      metrics = assigns.metrics.result
      meta = assigns.meta.result
      skip_imported_reason = assigns.skip_imported_reason.result

      max_value =
        results
        |> Enum.map(& &1.visitors)
        |> Enum.max()

      assigns =
        assign(assigns,
          max_value: max_value,
          results: results,
          metrics: metrics,
          meta: meta,
          skip_imported_reason: skip_imported_reason,
          empty?: Enum.empty?(results)
        )

      ~H"""
      <.no_data :if={@empty?} min_height={@min_height} />

      <div :if={not @empty?} class="h-full flex flex-col">
        <div style={"row-height: #{@row_height}px;"}>
          <.report_header key_label={@key_label} metrics={@metrics} col_min_width={@col_min_width} />
        </div>

        <div class="grow" style={"min-height: #{@data_container_height}px;"}>
          <.report_row
            :for={item <- @results}
            link_fn={assigns[:external_link_fn]}
            item={item}
            metrics={@metrics}
            bar_value={item.visitors}
            bar_max_value={@max_value}
            site={@site}
            params={@params}
            filter_dimension={@filter_dimension}
            row_height={@row_height}
            row_gap_height={@row_gap_height}
            col_min_width={@col_min_width}
          />
        </div>

        <div class="w-full text-center">
          <.details_link
            site={@site}
            params={@params}
            path="/pages"
          />
        </div>
      </div>
      """
    end
  end

  defp no_data(assigns) do
    ~H"""
    <div
      class="w-full h-full flex flex-col justify-center group-has-[.tile-tab.phx-click-loading]:hidden"
      style={"min-height: #{@min_height}px;"}
    >
      <div class="mx-auto font-medium text-gray-500 dark:text-gray-400">
        No data yet
      </div>
    </div>
    """
  end

  defp external_link(assigns) do
    url = if(assigns[:link_fn], do: assigns.link_fn.(assigns.item))

    assigns = assign(assigns, :url, url)

    ~H"""
    <.link
      :if={@url}
      target="_blank"
      rel="noreferrer"
      href={@url}
      class="w-4 h-4 invisible group-hover:visible"
    >
      <svg
        class="inline w-full h-full ml-1 -mt-1 text-gray-600 dark:text-gray-400"
        fill="currentColor"
        viewBox="0 0 20 20"
      >
        <path d="M11 3a1 1 0 100 2h2.586l-6.293 6.293a1 1 0 101.414 1.414L15 6.414V9a1 1 0 102 0V4a1 1 0 00-1-1h-5z">
        </path>
        <path d="M5 5a2 2 0 00-2 2v8a2 2 0 002 2h8a2 2 0 002-2v-3a1 1 0 10-2 0v3H5V7h3a1 1 0 000-2H5z">
        </path>
      </svg>
    </.link>
    """
  end

  defp report_header(assigns) do
    ~H"""
    <div class="pt-3 w-full text-xs font-bold tracking-wide text-gray-500 flex items-center dark:text-gray-400">
      <span class="grow truncate">{@key_label}</span>
      <div
        :for={metric <- @metrics}
        class={[metric.key, "text-right"]}
        style={"min-width: #{@col_min_width}px;"}
      >
        {metric.label}
      </div>
    </div>
    """
  end

  def report_row(assigns) do
    ~H"""
    <div style={"min-height: #{@row_height}px;"}>
      <div
        class="group flex w-full items-center hover:bg-gray-100/60 dark:hover:bg-gray-850 rounded-sm transition-colors duration-150"
        style={"margin-top: #{@row_gap_height}px;"}
      >
        <div class="grow w-full overflow-hidden">
          <Base.bar
            width={@bar_value}
            max_width={@bar_max_value}
            background_class="bg-green-50 group-hover:bg-green-100 dark:bg-gray-500/15 dark:group-hover:bg-gray-500/30"
          >
            <div class="flex justify-start px-2 py-1.5 group text-sm dark:text-gray-300 relative z-9 break-all w-full">
              <span class="w-full md:truncate">
                <Base.filter_link
                  class="max-w-max w-full flex items-center md:overflow-hidden hover:underline"
                  site={@site}
                  params={@params}
                  filter={[:is, @filter_dimension, [@item.name]]}
                >
                  {trim_name(@item.name, @col_min_width)}
                </Base.filter_link>
              </span>
              <.external_link item={@item} link_fn={assigns[:link_fn]} />
            </div>
          </Base.bar>
        </div>
        <div
          :for={metric <- @metrics}
          class="text-right"
          style={"width: #{@col_min_width}px; min-width: #{@col_min_width}px;"}
        >
          <span class="font-medium text-sm dark:text-gray-200 text-right">
            <Metric.value name={metric.key} value={@item[metric.key]} />
          </span>
        </div>
      </div>
    </div>
    """
  end

  defp details_link(assigns) do
    ~H"""
    <Base.dashboard_link
      class="leading-snug font-bold text-sm text-gray-500 dark:text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 transition-colors duration-150 tracking-wide"
      site={@site}
      params={@params}
      path={@path}
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
    </Base.dashboard_link>
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
end
