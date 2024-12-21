defmodule Plausible.ExportsTest do
  use Plausible.DataCase

  doctest Plausible.Exports, import: true

  # for e2e export->import tests please see Plausible.Imported.CSVImporterTest

  describe "export_queries/2" do
    test "returns named ecto queries" do
      queries = Plausible.Exports.export_queries(_site_id = 1)
      assert queries |> Map.values() |> Enum.all?(&match?(%Ecto.Query{}, &1))

      assert Map.keys(queries) == [
               "imported_browsers.csv",
               "imported_custom_events.csv",
               "imported_devices.csv",
               "imported_entry_pages.csv",
               "imported_exit_pages.csv",
               "imported_locations.csv",
               "imported_operating_systems.csv",
               "imported_pages.csv",
               "imported_sources.csv",
               "imported_visitors.csv"
             ]
    end

    test "with date range" do
      queries =
        Plausible.Exports.export_queries(_site_id = 1,
          date_range: Date.range(~D[2023-01-01], ~D[2024-03-12])
        )

      assert Map.keys(queries) == [
               "imported_browsers_20230101_20240312.csv",
               "imported_custom_events_20230101_20240312.csv",
               "imported_devices_20230101_20240312.csv",
               "imported_entry_pages_20230101_20240312.csv",
               "imported_exit_pages_20230101_20240312.csv",
               "imported_locations_20230101_20240312.csv",
               "imported_operating_systems_20230101_20240312.csv",
               "imported_pages_20230101_20240312.csv",
               "imported_sources_20230101_20240312.csv",
               "imported_visitors_20230101_20240312.csv"
             ]
    end

    test "with custom extension" do
      queries =
        Plausible.Exports.export_queries(_site_id = 1,
          extname: ".ch"
        )

      assert Map.keys(queries) == [
               "imported_browsers.ch",
               "imported_custom_events.ch",
               "imported_devices.ch",
               "imported_entry_pages.ch",
               "imported_exit_pages.ch",
               "imported_locations.ch",
               "imported_operating_systems.ch",
               "imported_pages.ch",
               "imported_sources.ch",
               "imported_visitors.ch"
             ]
    end
  end

  describe "stream_archive/3" do
    @describetag :tmp_dir

    setup do
      config = Keyword.replace!(Plausible.ClickhouseRepo.config(), :pool_size, 1)
      {:ok, ch: start_supervised!({Ch, config})}
    end

    test "creates zip archive", %{ch: ch, tmp_dir: tmp_dir} do
      queries = %{
        "1.csv" => from(n in fragment("numbers(3)"), select: n.number),
        "2.csv" =>
          from(n in fragment("numbers(3)"),
            select: [n.number, selected_as(n.number + n.number, :double)]
          )
      }

      DBConnection.run(ch, fn conn ->
        conn
        |> Plausible.Exports.stream_archive(queries, format: "CSVWithNames")
        |> Stream.into(File.stream!(Path.join(tmp_dir, "numbers.zip")))
        |> Stream.run()
      end)

      assert {:ok, files} =
               :zip.unzip(to_charlist(Path.join(tmp_dir, "numbers.zip")),
                 cwd: to_charlist(tmp_dir)
               )

      assert Enum.map(files, &Path.basename/1) == ["1.csv", "2.csv"]

      read_csv = fn file ->
        Enum.find(files, &(Path.basename(&1) == file))
        |> File.read!()
        |> NimbleCSV.RFC4180.parse_string(skip_headers: false)
      end

      assert read_csv.("1.csv") ==
               NimbleCSV.RFC4180.parse_string(
                 """
                 number
                 0
                 1
                 2
                 """,
                 skip_headers: false
               )

      assert read_csv.("2.csv") ==
               NimbleCSV.RFC4180.parse_string(
                 """
                 number,double
                 0,0
                 1,2
                 2,4
                 """,
                 skip_headers: false
               )
    end

    test "stops on error", %{ch: ch, tmp_dir: tmp_dir} do
      queries = %{
        "1.csv" => from(n in fragment("numbers(1000)"), select: n.number),
        "2.csv" => from(n in "no_such_table", select: n.number)
      }

      assert_raise Ch.Error, ~r/UNKNOWN_TABLE/, fn ->
        DBConnection.run(ch, fn conn ->
          conn
          |> Plausible.Exports.stream_archive(queries, format: "CSVWithNames")
          |> Stream.into(File.stream!(Path.join(tmp_dir, "failed.zip")))
          |> Stream.run()
        end)
      end

      assert {:error, :bad_eocd} =
               :zip.unzip(to_charlist(Path.join(tmp_dir, "failed.zip")),
                 cwd: to_charlist(tmp_dir)
               )
    end
  end
end
