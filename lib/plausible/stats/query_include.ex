defmodule Plausible.Stats.QueryInclude do
  defstruct [
    :imports,
    :imports_meta,
    :time_labels,
    :total_rows,
    :trim_relative_date_range,
    :compare,
    :compare_match_day_of_week,
    :legacy_time_on_page_cutoff
  ]

  @type date_range_tuple() :: {:date_range, Date.t(), Date.t()}
  # TODO:
  # @type datetime_range_tuple() :: {:date_range, DateTime.t(), DateTime.t()}

  @type t() :: %__MODULE__{
          imports: boolean(),
          imports_meta: boolean(),
          time_labels: boolean(),
          total_rows: boolean(),
          trim_relative_date_range: boolean(),
          compare: nil | :previous_period | :year_over_year | date_range_tuple(),
          compare_match_day_of_week: boolean(),
          legacy_time_on_page_cutoff: any()
        }
end
