defmodule Plausible.Imported.CSVImporter do
  @moduledoc """
  CSV importer stub.
  """

  use Plausible.Imported.Importer

  @name "CSV"

  @impl true
  def name(), do: @name

  @impl true
  def parse_args(%{"s3_path" => s3_path}), do: [s3_path: s3_path]

  @impl true
  def import_data(_site_import, _opts) do
    :ok
  end
end
