defmodule Plausible.Imported.CSVImporter do
  @moduledoc """
  CSV importer from either S3 for which it uses ClickHouse [s3 table function](https://clickhouse.com/docs/en/sql-reference/table-functions/s3)
  or from local storage for which it uses [input function.](https://clickhouse.com/docs/en/sql-reference/table-functions/input)
  """

  use Plausible.Imported.Importer
  import Ecto.Query, only: [from: 2]

  @impl true
  def name(), do: :csv

  @impl true
  def label(), do: "CSV"

  @impl true
  def email_template(), do: "csv_import.html"

  @impl true
  def parse_args(%{"uploads" => uploads, "storage" => storage}) do
    [uploads: uploads, storage: storage]
  end

  @impl true
  def import_data(site_import, opts) do
    storage = Keyword.fetch!(opts, :storage)
    uploads = Keyword.fetch!(opts, :uploads)

    if storage == "local" do
      # we need to remove the imported files from local storage
      # after the importer has completed or ran out of attempts
      paths = Enum.map(uploads, &Map.fetch!(&1, "local_path"))

      Oban.insert!(
        Plausible.Workers.LocalImportAnalyticsCleaner.new(
          %{"import_id" => site_import.id, "paths" => paths},
          schedule_in: _one_hour = 3600
        )
      )
    end

    {:ok, ch} =
      Plausible.IngestRepo.config()
      |> Keyword.replace!(:pool_size, 1)
      |> Ch.start_link()

    case storage do
      "s3" -> import_s3(ch, site_import, uploads)
      "local" -> import_local(ch, site_import, uploads)
    end
  rescue
    # we are cancelling on any argument or ClickHouse errors, assuming they are permanent
    e in [ArgumentError, Ch.Error] ->
      # see Plausible.Imported.Importer for more details on transient vs permanent errors
      {:error, Exception.message(e)}
  end

  def on_success(site_import, _extra_data) do
    has_scroll_depth? =
      Plausible.ClickhouseRepo.exists?(
        from(i in "imported_pages",
          where: i.site_id == ^site_import.site_id,
          where: i.import_id == ^site_import.id,
          where: not is_nil(i.scroll_depth),
          select: 1
        )
      )

    if has_scroll_depth? do
      site_import
      |> Ecto.Changeset.change(%{has_scroll_depth: true})
      |> Plausible.Repo.update!()
    end

    :ok
  end

  defp import_s3(ch, site_import, uploads) do
    %{
      id: import_id,
      site_id: site_id,
      start_date: start_date,
      end_date: end_date
    } = site_import

    %{access_key_id: s3_access_key_id, secret_access_key: s3_secret_access_key} =
      Plausible.S3.import_clickhouse_credentials()

    Enum.each(uploads, fn upload ->
      %{"filename" => filename, "s3_url" => s3_url} = upload

      {table, _, _} = parse_filename!(filename)
      s3_structure = input_structure!(table)
      s3_columns = input_columns!(table)

      statement =
        """
        INSERT INTO {table:Identifier}(site_id,import_id,#{s3_columns}) \
        SELECT {site_id:UInt64}, {import_id:UInt64}, #{s3_columns} \
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
  end

  defp import_local(ch, site_import, uploads) do
    %{
      id: import_id,
      site_id: site_id,
      start_date: start_date,
      end_date: end_date
    } = site_import

    DBConnection.run(
      ch,
      fn conn ->
        Enum.each(uploads, fn upload ->
          %{"filename" => filename, "local_path" => local_path} = upload

          {table, _, _} = parse_filename!(filename)
          input_structure = input_structure!(table)
          input_columns = input_columns!(table)

          statement =
            """
            INSERT INTO {table:Identifier}(site_id,import_id,#{input_columns}) \
            SELECT {site_id:UInt64}, {import_id:UInt64}, #{input_columns} \
            FROM input({input_structure:String}) \
            WHERE date >= {start_date:Date} AND date <= {end_date:Date} \
            FORMAT CSVWithNames
            """

          params = %{
            "table" => table,
            "site_id" => site_id,
            "import_id" => import_id,
            "input_structure" => input_structure,
            "start_date" => start_date,
            "end_date" => end_date
          }

          # we are reading in 512KB chunks for better performance
          # the default would've been line by line (not great for a CSV)
          File.stream!(local_path, 512_000)
          |> Stream.into(Ch.stream(conn, statement, params))
          |> Stream.run()
        end)
      end,
      timeout: :infinity
    )
  end

  input_structures = %{
    "imported_browsers" =>
      "date Date, browser String, browser_version String, visitors UInt64, visits UInt64, visit_duration UInt64, bounces UInt32, pageviews UInt64",
    "imported_devices" =>
      "date Date, device String, visitors UInt64, visits UInt64, visit_duration UInt64, bounces UInt32, pageviews UInt64",
    "imported_entry_pages" =>
      "date Date, entry_page String, visitors UInt64, entrances UInt64, visit_duration UInt64, bounces UInt32, pageviews UInt64",
    "imported_exit_pages" =>
      "date Date, exit_page String, visitors UInt64, visit_duration UInt64, exits UInt64, bounces UInt32, pageviews UInt64",
    "imported_custom_events" =>
      "date Date, name String, link_url String, path String, visitors UInt64, events UInt64",
    "imported_locations" =>
      "date Date, country String, region String, city UInt64, visitors UInt64, visits UInt64, visit_duration UInt64, bounces UInt32, pageviews UInt64",
    "imported_operating_systems" =>
      "date Date, operating_system String, operating_system_version String, visitors UInt64, visits UInt64, visit_duration UInt64, bounces UInt32, pageviews UInt64",
    "imported_pages" =>
      "date Date, hostname String, page String, visits UInt64, visitors UInt64, pageviews UInt64, scroll_depth Nullable(UInt64), pageleave_visitors UInt64",
    "imported_sources" =>
      "date Date, source String, referrer String, utm_source String, utm_medium String, utm_campaign String, utm_content String, utm_term String, pageviews UInt64, visitors UInt64, visits UInt64, visit_duration UInt64, bounces UInt32",
    "imported_visitors" =>
      "date Date, visitors UInt64, pageviews UInt64, bounces UInt64, visits UInt64, visit_duration UInt64"
  }

  @doc """
  Extracts min/max date range from a list of uploads.

  Examples:

      iex> date_range([
      ...>   %{"filename" => "imported_devices_20190101_20210101.csv"},
      ...>   "pages_20200101_20220101.csv"
      ...> ])
      Date.range(~D[2019-01-01], ~D[2022-01-01])

      iex> date_range([])
      nil

  """
  @spec date_range([String.t() | %{String.t() => String.t()}, ...]) :: Date.Range.t() | nil
  def date_range([_ | _] = uploads), do: date_range(uploads, _start_date = nil, _end_date = nil)
  def date_range([]), do: nil

  defp date_range([upload | uploads], prev_start_date, prev_end_date) do
    filename =
      case upload do
        %{"filename" => filename} -> filename
        filename when is_binary(filename) -> filename
      end

    {_table, start_date, end_date} = parse_filename!(filename)

    start_date =
      if prev_start_date do
        Enum.min([start_date, prev_start_date], Date)
      else
        start_date
      end

    end_date =
      if prev_end_date do
        Enum.max([end_date, prev_end_date], Date)
      else
        end_date
      end

    date_range(uploads, start_date, end_date)
  end

  defp date_range([], first, last), do: Date.range(first, last)

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

      iex> parse_filename!("devices_00010101_20250101.csv")
      {"imported_devices", ~D[0001-01-01], ~D[2025-01-01]}

  """
  @spec parse_filename!(String.t()) ::
          {table :: String.t(), start_date :: Date.t(), end_date :: Date.t()}
  def parse_filename!(filename)

  for {table, input_structure} <- input_structures do
    defp input_structure!(unquote(table)), do: unquote(input_structure)

    input_columns =
      input_structure
      |> String.split(",", trim: true)
      |> Enum.map_join(",", fn kv ->
        [col, _type] = String.split(kv)
        String.trim(col)
      end)

    defp input_columns!(unquote(table)), do: unquote(input_columns)

    def parse_filename!(
          <<unquote(table)::bytes, ?_, start_date::8-bytes, ?_, end_date::8-bytes, ".csv">>
        ) do
      {unquote(table), parse_date!(start_date), parse_date!(end_date)}
    end

    "imported_" <> name = table

    def parse_filename!(
          <<unquote(name)::bytes, ?_, start_date::8-bytes, ?_, end_date::8-bytes, ".csv">>
        ) do
      {unquote(table), parse_date!(start_date), parse_date!(end_date)}
    end
  end

  def parse_filename!(_filename) do
    raise ArgumentError, "invalid filename"
  end

  @doc """
  Checks if the provided filename conforms to the expected format.

  Examples:

      iex> valid_filename?("my_data.csv")
      false

      iex> valid_filename?("imported_devices_00010101_20250101.csv")
      true

      iex> valid_filename?("devices_00010101_20250101.csv")
      true

  """
  @spec valid_filename?(String.t()) :: boolean
  def valid_filename?(filename) do
    try do
      parse_filename!(filename)
    else
      _ -> true
    rescue
      _ -> false
    end
  end

  @doc """
  Extracts the table name from the provided filename.

  Raises if the filename doesn't conform to the expected format.

  Examples:

      iex> extract_table("my_data.csv")
      ** (ArgumentError) invalid filename

      iex> extract_table("imported_devices_00010101_20250101.csv")
      "imported_devices"

      iex> extract_table("devices_00010101_20250101.csv")
      "imported_devices"

  """
  @spec extract_table(String.t()) :: String.t()
  def extract_table(filename) do
    {table, _start_date, _end_date} = parse_filename!(filename)
    table
  end

  @doc """
  Returns local directory for CSV imports storage.

  Builds upon `$DATA_DIR`, `$PERSISTENT_CACHE_DIR` or `$DEFAULT_DATA_DIR` (if set) and falls back to /tmp.

  `$DEFAULT_DATA_DIR` is set to `/var/lib/plausible` in container images.

  Examples:

      iex> local_dir = local_dir(_site_id = 37)
      iex> String.ends_with?(local_dir, "/plausible-imports/37")
      true

  """
  def local_dir(site_id) do
    data_dir = Application.get_env(:plausible, :data_dir)
    Path.join([data_dir || System.tmp_dir!(), "plausible-imports", Integer.to_string(site_id)])
  end
end
