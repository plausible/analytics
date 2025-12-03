defmodule Plausible.Stats.ParsedQueryParams do
  @moduledoc false

  defstruct [
    :now,
    :input_date_range,
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
    [_ | _] = metrics = Map.fetch!(params, :metrics)

    %__MODULE__{
      now: params[:now],
      input_date_range: Map.fetch!(params, :input_date_range),
      metrics: metrics,
      filters: params[:filters] || [],
      dimensions: params[:dimensions] || [],
      order_by: params[:order_by],
      pagination: Map.merge(@default_pagination, params[:pagination] || %{}),
      include: Map.merge(@default_include, params[:include] || %{})
    }
  end
end
