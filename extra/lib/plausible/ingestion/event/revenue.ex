defmodule Plausible.Ingestion.Event.Revenue do
  @moduledoc """
  Revenue specific functions for the ingestion scope
  """

  def get_revenue_attrs(
        %Plausible.Ingestion.Event{request: %{revenue_source: %Money{} = revenue_source}} = event
      ) do
    matching_goal =
      Enum.find(event.site.revenue_goals, &(&1.event_name == event.clickhouse_event_attrs.name))

    cond do
      is_nil(matching_goal) ->
        %{}

      matching_goal.currency == revenue_source.currency ->
        %{
          revenue_source_amount: Money.to_decimal(revenue_source),
          revenue_source_currency: to_string(revenue_source.currency),
          revenue_reporting_amount: Money.to_decimal(revenue_source),
          revenue_reporting_currency: to_string(revenue_source.currency)
        }

      matching_goal.currency != revenue_source.currency ->
        converted =
          Money.to_currency!(revenue_source, matching_goal.currency)

        %{
          revenue_source_amount: Money.to_decimal(revenue_source),
          revenue_source_currency: to_string(revenue_source.currency),
          revenue_reporting_amount: Money.to_decimal(converted),
          revenue_reporting_currency: to_string(converted.currency)
        }
    end
  end

  def get_revenue_attrs(_event), do: %{}
end
