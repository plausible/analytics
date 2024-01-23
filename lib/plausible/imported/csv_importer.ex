defmodule Plausible.Imported.CSVImporter do
  @moduledoc """
  CSV importer stub.
  """
  @name "CSV"

  def name(), do: @name

  def create_job(site, opts) do
    s3_path = Keyword.fetch!(opts, :s3_path)

    Plausible.Workers.ImportAnalytics.new(%{
      "source" => @name,
      "site_id" => site.id,
      "s3_path" => s3_path
    })
  end

  def parse_args(%{"s3_path" => s3_path}), do: [s3_path: s3_path]

  def import(_site, _opts) do
    :ok
  end
end
