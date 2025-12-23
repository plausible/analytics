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
            include: %Plausible.Stats.QueryInclude{}

  def new!(params) when is_map(params) do
    struct!(__MODULE__, Map.to_list(params))
  end

  def set(params, keywords) do
    struct!(params, keywords)
  end

  def set_include(params, key, value) do
    struct!(params, include: struct!(params.include, [{key, value}]))
  end

  @props_prefix "event:props:"

  def add_or_replace_filter(%__MODULE__{filters: filters} = parsed_query_params, new_filter) do
    [_, new_filter_dimension, _] = new_filter

    prop_filter? = String.starts_with?(new_filter_dimension, @props_prefix)

    new_filters =
      filters
      |> Enum.reject(fn [_, existing_filter_dimension, _] ->
        existing_filter_dimension == new_filter_dimension or
          (prop_filter? and String.starts_with?(existing_filter_dimension, @props_prefix))
      end)
      |> Enum.concat([new_filter])

    struct!(parsed_query_params, filters: new_filters)
  end
end
