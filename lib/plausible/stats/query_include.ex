defmodule Plausible.Stats.QueryInclude do
  @moduledoc false

  defstruct imports: false,
            imports_meta: false,
            time_labels: false,
            # `time_label_result_indices` is a convenience for our main graph component. It
            # is not yet ready for a public API release because it should also account for
            # breakdowns by multiple dimensions (time + non-time). Also, at this point it is
            # still unclear whether `time_labels` will stay in the public API or not.
            time_label_result_indices: false,
            # Another flag to simplify frontend code by not having to repeat the logic defining
            # default values for metrics (especially revenue metrics).
            empty_metrics: false,
            present_index: false,
            partial_time_labels: false,
            total_rows: false,
            trim_relative_date_range: false,
            compare: nil,
            compare_match_day_of_week: false,
            legacy_time_on_page_cutoff: nil,
            drop_unavailable_time_on_page: false,
            drop_unavailable_revenue_metrics: false

  @type date_range_tuple() :: {:date_range, Date.t(), Date.t()}
  @type datetime_range_tuple() :: {:datetime_range, DateTime.t(), DateTime.t()}

  @type t() :: %__MODULE__{
          imports: boolean(),
          imports_meta: boolean(),
          time_labels: boolean(),
          time_label_result_indices: boolean(),
          empty_metrics: boolean(),
          present_index: boolean(),
          partial_time_labels: boolean(),
          total_rows: boolean(),
          trim_relative_date_range: boolean(),
          compare:
            nil | :previous_period | :year_over_year | date_range_tuple() | datetime_range_tuple(),
          compare_match_day_of_week: boolean(),
          legacy_time_on_page_cutoff: any(),
          drop_unavailable_time_on_page: boolean(),
          drop_unavailable_revenue_metrics: boolean()
        }
end
