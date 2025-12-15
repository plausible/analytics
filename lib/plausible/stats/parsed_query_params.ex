defmodule Plausible.Stats.ParsedQueryParams do
  @moduledoc false

  defstruct input_date_range: nil,
            # `relative_date` is a convenience currently exclusive to the internal
            # dashboard API for constructing datetime ranges. It adds the ability
            # to use `day`, `month` and `year` periods relative to a specific date.
            # E.g.: `?period=month&date=2021-01-15` will query the entire month of
            # January 2021. In the public API it is always today in site.timezone.
            relative_date: nil,
            metrics: [],
            filters: [],
            dimensions: [],
            order_by: nil,
            pagination: nil,
            include: nil

  def new!(params) when is_map(params) do
    struct!(__MODULE__, Map.to_list(params))
  end
end
