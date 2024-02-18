defmodule Plausible.Imports do
  @moduledoc """
  Contains functions to import pre-aggregated data into `imported_*` tables.
  """

  @doc """
  Creates a collectable stream which pipes the data to an `imported_*` table.

  Example usage:

      {:ok, pool} = Ch.start_link(pool_size: 1)

      DBConnection.run(pool, fn conn ->
        File.stream!("imported_browsers.csv", _64kb = 64000)
        |> Stream.into(import_stream(conn, _site_id = 12, _table = "imported_browsers", _format = "CSVWithNames"))
        |> Stream.run()
      end)

  """
  @spec import_stream(DBConnection.t(), pos_integer, String.t(), String.t(), [Ch.query_option()]) ::
          Ch.Stream.t()
  def import_stream(conn, site_id, table, format, opts \\ []) do
    :ok = ensure_supported_format(format)

    statement =
      [
        "INSERT INTO {table:Identifier} SELECT {site_id:UInt64} AS site_id, * FROM input('",
        input_structure(table),
        "') FORMAT ",
        format,
        ?\n
      ]

    Ch.stream(conn, statement, %{"table" => table, "site_id" => site_id}, opts)
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
    def input_structure(unquote(table)), do: unquote(input_structure)
  end

  def input_structure(table) do
    raise ArgumentError, "table #{table} is not supported for data import"
  end

  for format <- ["Native", "CSVWithNames"] do
    defp ensure_supported_format(unquote(format)), do: :ok
  end

  defp ensure_supported_format(format) do
    raise ArgumentError, "format #{format} is not supported for data import"
  end
end
