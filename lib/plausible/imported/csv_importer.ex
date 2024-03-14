defmodule Plausible.Imported.CSVImporter do
  @moduledoc """
  CSV importer from S3 that uses ClickHouse [s3 table function.](https://clickhouse.com/docs/en/sql-reference/table-functions/s3)
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
    %{
      id: import_id,
      site_id: site_id,
      start_date: start_date,
      end_date: end_date
    } = site_import

    uploads = Keyword.fetch!(opts, :uploads)

    %{access_key_id: s3_access_key_id, secret_access_key: s3_secret_access_key} =
      Plausible.S3.import_clickhouse_credentials()

    {:ok, ch} =
      Plausible.IngestRepo.config()
      |> Keyword.replace!(:pool_size, 1)
      |> Ch.start_link()

    Enum.each(uploads, fn upload ->
      %{"filename" => filename, "s3_url" => s3_url} = upload

      {table, _, _} = parse_filename!(filename)
      s3_structure = input_structure!(table)

      statement =
        """
        INSERT INTO {table:Identifier} \
        SELECT {site_id:UInt64} AS site_id, *, {import_id:UInt64} AS import_id \
        FROM s3({s3_url:String},{s3_access_key_id:String},{s3_secret_access_key:String},{s3_format:String},{s3_structure:String}) \
        WHERE date >= {start_date:Date} AND date <= {end_date:Date}\
        """

      params =
        %{
          "table" => table,
          "site_id" => site_id,
          "import_id" => import_id,
          "s3_url" => s3_url,
          "s3_access_key_id" => s3_access_key_id,
          "s3_secret_access_key" => s3_secret_access_key,
          "s3_format" => "CSVWithNames",
          "s3_structure" => s3_structure,
          "start_date" => start_date,
          "end_date" => end_date
        }

      Ch.query!(ch, statement, params, timeout: :infinity)
    end)
  rescue
    # we are cancelling on any argument or ClickHouse errors
    e in [ArgumentError, Ch.Error] ->
      {:error, Exception.message(e)}
  end

  input_structures = %{
    "imported_browsers" =>
      "date Date, browser String, visitors UInt64, visits UInt64, visit_duration UInt64, bounces UInt32",
    "imported_devices" =>
      "date Date, device String, visitors UInt64, visits UInt64, visit_duration UInt64, bounces UInt32",
    "imported_entry_pages" =>
      "date Date, entry_page String, visitors UInt64, entrances UInt64, visit_duration UInt64, bounces UInt32",
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

  @doc """
  Extracts min/max date range from a list of uploads.

  Examples:

      iex> date_range([
      ...>   %{"filename" => "imported_devices_20190101_20210101.csv"},
      ...>   "imported_pages_20200101_20220101.csv"
      ...> ])
      Date.range(~D[2019-01-01], ~D[2022-01-01])

      iex> date_range([])
      ** (ArgumentError) empty uploads

  """
  @spec date_range([String.t() | %{String.t() => String.t()}, ...]) :: Date.Range.t()
  def date_range([_ | _] = uploads), do: date_range(uploads, _start_date = nil, _end_date = nil)
  def date_range([]), do: raise(ArgumentError, "empty uploads")

  defp date_range([upload | uploads], prev_start_date, prev_end_date) do
    filename =
      case upload do
        %{"filename" => filename} -> filename
        filename when is_binary(filename) -> filename
      end

    {_table, start_date, end_date} = parse_filename!(filename)

    start_date =
      if prev_start_date do
        min_date(start_date, prev_start_date)
      else
        start_date
      end

    end_date =
      if prev_end_date do
        max_date(end_date, prev_end_date)
      else
        end_date
      end

    date_range(uploads, start_date, end_date)
  end

  defp date_range([], first, last), do: Date.range(first, last)

  defp min_date(d1, d2) do
    if Date.compare(d1, d2) == :lt, do: d1, else: d2
  end

  defp max_date(d1, d2) do
    if Date.compare(d1, d2) == :gt, do: d1, else: d2
  end

  @spec parse_date!(String.t()) :: Date.t()
  defp parse_date!(date) do
    date |> Timex.parse!("{YYYY}{0M}{0D}") |> NaiveDateTime.to_date()
  end

  @doc """
  Extracts table name and min/max dates from the filename.

  Examples:

      iex> parse_filename!("my_data.csv")
      ** (ArgumentError) invalid filename

      iex> parse_filename!("imported_devices_00010101_20250101.csv")
      {"imported_devices", ~D[0001-01-01], ~D[2025-01-01]}

  """
  @spec parse_filename!(String.t()) ::
          {table :: String.t(), start_date :: Date.t(), end_date :: Date.t()}
  def parse_filename!(filename)

  for {table, input_structure} <- input_structures do
    defp input_structure!(unquote(table)), do: unquote(input_structure)

    def parse_filename!(
          <<unquote(table)::bytes, ?_, start_date::8-bytes, ?_, end_date::8-bytes, ".csv">>
        ) do
      {unquote(table), parse_date!(start_date), parse_date!(end_date)}
    end
  end

  def parse_filename!(_filename) do
    raise ArgumentError, "invalid filename"
  end
end
