defmodule Plausible.DashboardTestUtils do
  @moduledoc false

  import Plausible.Test.Support.HTML

  def get_in_report_list(%LazyHTML{} = report_list, opts) do
    selector =
      case opts do
        :key_label ->
          ~s|[data-test-id="key-label"]|

        [metric_label: idx] ->
          ~s|[data-test-id="metric-#{idx}-label"]|

        [item_name: idx] ->
          ~s|[data-test-id="item-#{idx}-name"]|

        opts ->
          item_idx = Keyword.fetch!(opts, :item)
          metric_idx = Keyword.fetch!(opts, :metric)

          ~s|[data-test-id="item-#{item_idx}-metric-#{metric_idx}"]|
      end

    if element_exists?(report_list, selector) do
      text_of_element(report_list, selector)
    else
      nil
    end
  end
end
