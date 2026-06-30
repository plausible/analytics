defmodule Plausible.Stats do
  use Plausible
  use Plausible.ClickhouseRepo

  alias Plausible.Stats.{
    CurrentVisitors,
    FilterSuggestions,
    QueryRunner
  }

  def query(site, query) do
    QueryRunner.run(site, query)
  end

  def current_visitors(site, duration \\ Duration.new!(minute: -5)) do
    CurrentVisitors.current_visitors(site, duration)
  end

  on_ee do
    def funnel(site, query, funnel) do
      Plausible.Stats.Funnel.funnel(site, query, funnel)
    end
  end

  def filter_suggestions(site, query, filter_name, filter_search) do
    FilterSuggestions.filter_suggestions(site, query, filter_name, filter_search)
  end

  def custom_prop_value_filter_suggestions(site, query, prop_key, filter_search) do
    FilterSuggestions.custom_prop_value_filter_suggestions(site, query, prop_key, filter_search)
  end
end
