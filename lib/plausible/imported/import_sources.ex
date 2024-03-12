defmodule Plausible.Imported.ImportSources do
  @moduledoc """
  Definitions of import sources.
  """

  @sources [
    Plausible.Imported.GoogleAnalytics4,
    Plausible.Imported.UniversalAnalytics,
    Plausible.Imported.NoopImporter,
    Plausible.Imported.CSVImporter
  ]

  @sources_map Map.new(@sources, &{&1.name(), &1})

  @source_names Enum.map(@sources, & &1.name())

  @spec names() :: [atom()]
  def names(), do: @source_names

  @spec by_name(atom()) :: module()
  def by_name(name) do
    Map.fetch!(@sources_map, name)
  end
end
