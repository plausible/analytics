defmodule Plausible.Stats.QueryInclude do
  @moduledoc false

  defstruct imports: false,
            imports_meta: false,
            time_labels: false,
            total_rows: false,
            trim_relative_date_range: false,
            compare: nil,
            compare_match_day_of_week: false,
            legacy_time_on_page_cutoff: nil,
            drop_unavailable_time_on_page: false

  @type date_range_tuple() :: {:date_range, Date.t(), Date.t()}
  @type datetime_range_tuple() :: {:datetime_range, DateTime.t(), DateTime.t()}

  @type t() :: %__MODULE__{
          imports: boolean(),
          imports_meta: boolean(),
          time_labels: boolean(),
          total_rows: boolean(),
          trim_relative_date_range: boolean(),
          compare:
            nil | :previous_period | :year_over_year | date_range_tuple() | datetime_range_tuple(),
          compare_match_day_of_week: boolean(),
          legacy_time_on_page_cutoff: any(),
          drop_unavailable_time_on_page: boolean()
        }
end
