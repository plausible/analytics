defmodule Plausible.Imported.CSVImporter do
  @moduledoc """
  CSV importer stub.
  """

  use Plausible.Imported.Importer

  @impl true
  def name(), do: :csv

  @impl true
  def label(), do: "CSV"

  # NOTE: change it once CSV import is implemented
  @impl true
  def email_template(), do: "google_analytics_import.html"

  @impl true
  def parse_args(%{"s3_path" => s3_path}), do: [s3_path: s3_path]

  @impl true
  def import_data(_site_import, _opts) do
    :ok
  end
end
