defmodule Plausible.ImportsTest do
  use Plausible.DataCase
  import Ecto.Query

  describe "import_stream/4" do
    test "for imported_browsers.csv" do
      site_id = :rand.uniform(10_000_000)
      tmp_path = tmp_touch("imported_browsers.csv")

      File.write!(tmp_path, """
      browser,date,visitors,visits,visit_duration,bounces
      Chrome,2023-10-20,1,1,200,1
      Edge,2023-10-20,1,1,100,1
      Chrome,2023-10-21,2,3,130,1
      """)

      DBConnection.run(ch(), fn conn ->
        File.stream!(tmp_path)
        |> Stream.into(
          Plausible.Imports.import_stream(conn, site_id, "imported_browsers", "CSVWithNames")
        )
        |> Stream.run()
      end)

      selected_columns = [
        :site_id,
        :date,
        :browser,
        :visitors,
        :visits,
        :visit_duration,
        :bounces
      ]

      assert "imported_browsers"
             |> where(site_id: ^site_id)
             |> select([b], map(b, ^selected_columns))
             |> Plausible.ClickhouseRepo.all() == [
               %{
                 date: ~D[2023-10-20],
                 site_id: site_id,
                 browser: "Chrome",
                 visitors: 1,
                 visits: 1,
                 visit_duration: 200,
                 bounces: 1
               },
               %{
                 date: ~D[2023-10-20],
                 site_id: site_id,
                 browser: "Edge",
                 visitors: 1,
                 visits: 1,
                 visit_duration: 100,
                 bounces: 1
               },
               %{
                 date: ~D[2023-10-21],
                 site_id: site_id,
                 browser: "Chrome",
                 visitors: 2,
                 visits: 3,
                 visit_duration: 130,
                 bounces: 1
               }
             ]
    end

    @tag :skip
    test "for imported_devices.csv"
    @tag :skip
    test "for imported_entry_pages.csv"
    @tag :skip
    test "for imported_exit_pages.csv"
    @tag :skip
    test "for imported_locations.csv"
    @tag :skip
    test "for imported_operating_systems.csv"
    @tag :skip
    test "for imported_pages.csv"
    @tag :skip
    test "for imported_sources.csv"
    @tag :skip
    test "for imported_visitors.csv"
  end

  defp ch do
    {:ok, conn} =
      Plausible.IngestRepo.config()
      |> Keyword.replace!(:pool_size, 1)
      |> Ch.start_link()

    conn
  end

  defp tmp_touch(name) do
    tmp_path = Path.join(System.tmp_dir!(), name)
    File.touch!(tmp_path)
    on_exit(fn -> File.rm!(tmp_path) end)
    tmp_path
  end
end
