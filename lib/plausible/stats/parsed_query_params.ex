defmodule Plausible.Stats.ParsedQueryParams do
  @moduledoc false

  defstruct [
    :input_date_range,
    # `relative_date` is a convenience currently exclusive to the internal
    # dashboard API for constructing datetime ranges. It adds the ability
    # to use `day`, `month` and `year` periods relative to a specific date.
    # E.g.: `?period=month&date=2021-01-15` will query the entire month of
    # January 2021. In the public API it is always today in site.timezone.
    :relative_date,
    :metrics,
    :filters,
    :dimensions,
    :order_by,
    :pagination,
    :include
  ]

  @default_include %{
    imports: false,
    # `include.imports_meta` can be true even when `include.imports`
    # is false. Even if we don't want to include imported data, we
    # might still want to know whether imported data can be toggled
    # on/off on the dashboard.
    imports_meta: false,
    time_labels: false,
    total_rows: false,
    trim_relative_date_range: false,
    comparisons: nil,
    legacy_time_on_page_cutoff: nil
  }

  def default_include(), do: @default_include

  @default_pagination %{
    limit: 10_000,
    offset: 0
  }

  def default_pagination(), do: @default_pagination

  def new!(params) when is_map(params) do
    %__MODULE__{
      relative_date: params[:relative_date],
      input_date_range: Map.fetch!(params, :input_date_range),
      metrics: params[:metrics],
      filters: params[:filters] || [],
      dimensions: params[:dimensions] || [],
      order_by: params[:order_by],
      pagination: Map.merge(@default_pagination, params[:pagination] || %{}),
      include: Map.merge(@default_include, params[:include] || %{})
    }
  end
end
