defmodule Plausible.Imported.CSVImporter do
  @moduledoc """
  CSV importer from S3.
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
  def parse_args(%{"uploads" => uploads}), do: [uploads: uploads]

  @impl true
  def import_data(site_import, opts) do
    %{id: import_id, site_id: site_id} = site_import
    uploads = Keyword.fetch!(opts, :uploads)

    %{access_key_id: s3_access_key_id, secret_access_key: s3_secret_access_key} =
      Plausible.S3.import_clickhouse_credentials()

    {:ok, ch} =
      Plausible.IngestRepo.config()
      |> Keyword.replace!(:pool_size, 1)
      |> Ch.start_link()

    # TODO what if it succeeds for some tables and then fails? Should the other tables be dropped?
    ranges =
      Enum.each(uploads, fn upload ->
        %{"filename" => filename, "s3_path" => s3_path} = upload

        ".csv" = Path.extname(filename)
        table = Path.rootname(filename)
        ensure_importable_table!(table)

        s3_structure = input_structure!(table)
        s3_url = Plausible.S3.import_clickhouse_url(s3_path)

        statement =
          """
          INSERT INTO {table:Identifier} \
          SELECT {site_id:UInt64} AS site_id, {import_id:UInt64} AS import_id, * \
          FROM s3({s3_url:String},{s3_access_key_id:String},{s3_secret_access_key:String},{s3_format:String},{s3_structure:String})\
          """

        params = %{
          "table" => table,
          "site_id" => site_id,
          "import_id" => import_id,
          "s3_url" => s3_url,
          "s3_access_key_id" => s3_access_key_id,
          "s3_secret_access_key" => s3_secret_access_key,
          "s3_format" => "CSVWithNames",
          "s3_structure" => s3_structure
        }

        Ch.query!(ch, statement, params, timeout: :infinity)

        %Ch.Result{rows: [[min_date, max_date]]}

        Ch.query!(
          ch,
          "SELECT min(date), max(date) FROM {table:Identifier} WHERE site_id = {site_id:UInt64} AND import_id = {import_id:UInt64}",
          %{"table" => table, "site_id" => site_id, "import_id" => import_id}
        )

        Date.range(min_date, max_date)
      end)

    {:ok,
     %{
       start_date: Enum.min_by(ranges, & &1.first),
       end_date: Enum.max_by(ranges, & &1.last)
     }}
  end

  input_structures = %{
    "imported_browsers" =>
      "date Date, browser String, visitors UInt64, visits UInt64, visit_duration UInt64, bounces UInt32",
    "imported_devices" =>
      "date Date, device String, visitors UInt64, visits UInt64, visit_duration UInt64, bounces UInt32",
    "imported_entry_pages" =>
      "date Date, entry_page String, visitors UInt64, entrances UInt64, visit_duration UInt64, bounces UInt64",
    "imported_exit_pages" => "date Date, exit_page String, visitors UInt64, exits UInt64",
    "imported_locations" =>
      "date Date, country String, region String, city UInt64, visitors UInt64, visits UInt64, visit_duration UInt64, bounces UInt32",
    "imported_operating_systems" =>
      "date Date, operating_system String, visitors UInt64, visits UInt64, visit_duration UInt64, bounces UInt32",
    "imported_pages" =>
      "date Date, hostname String, page String, visitors UInt64, pageviews UInt64, exits UInt64, time_on_page UInt64",
    "imported_sources" =>
      "date Date, source String, utm_medium String, utm_campaign String, utm_content String, utm_term String, visitors UInt64, visits UInt64, visit_duration UInt64, bounces UInt32",
    "imported_visitors" =>
      "date Date, visitors UInt64, pageviews UInt64, bounces UInt64, visits UInt64, visit_duration UInt64"
  }

  for {table, input_structure} <- input_structures do
    defp input_structure!(unquote(table)), do: unquote(input_structure)
    defp ensure_importable_table!(unquote(table)), do: :ok

    defp parse_filename!(
           <<unquote(table)::bytes, ?_, start_date::8-bytes, ?_, end_date::8-bytes, ".csv">>
         ) do
      [
        unquote(table),
        Timex.parse!(start_date, "{YYYY}{0M}{0D}"),
        Timex.parse!(end_date, "{YYYY}{0M}{0D}")
      ]
    end
  end

  defp ensure_importable_table!(table) do
    raise ArgumentError, "table #{table} is not supported for data import"
  end

  defp parse_filename!(filename) do
    raise ArgumentError,
          "filename #{inspect(filename)} " <>
            ~S[ does not conform to the expected "#{table}_#{start_date}_#{end_date}.csv" format]
  end
end
