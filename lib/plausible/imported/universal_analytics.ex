defmodule Plausible.Imported.UniversalAnalytics do
  @moduledoc """
  Import implementation for Universal Analytics.

  NOTE: As importing from UA is no longer supported, this module
  is only used to support rendering existing imports.
  """

  use Plausible.Imported.Importer

  @impl true
  def name(), do: :universal_analytics

  @impl true
  def label(), do: "Google Analytics"

  @impl true
  def email_template(), do: "google_analytics_import.html"

  @impl true
  def parse_args(_args) do
    raise "Importing data not supported"
  end

  @impl true
  def import_data(_site_import, _opts) do
    raise "Importing data not supported"
  end
end
