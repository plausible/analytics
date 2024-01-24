defmodule Plausible.Imported.ImportSources do
  @moduledoc """
  Definitions of import sources.
  """

  @sources [
    Plausible.Imported.UniversalAnalytics,
    Plausible.Imported.NoopImporter,
    Plausible.Imported.CSVImporter
  ]

  @sources_map Map.new(@sources, &{&1.name(), &1})

  @source_names Enum.map(@sources, & &1.name())

  def names(), do: @source_names

  def by_name(name) do
    Map.fetch!(@sources_map, name)
  end
end
