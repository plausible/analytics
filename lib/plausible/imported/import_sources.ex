defmodule Plausible.Imported.ImportSources do
  @moduledoc """
  Definitions of import sources.
  """

  @sources [
    Plausible.Imported.UniversalAnalytics,
    Plausible.Imported.NoopImporter
  ]

  @sources_map Map.new(@sources, &{&1.name(), &1})

  def by_name(name) do
    Map.fetch!(@sources_map, name)
  end
end
