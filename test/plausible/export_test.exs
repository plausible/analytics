defmodule Plausible.ExportTest do
  use Plausible.DataCase

  test "it works" do
    site = insert(:site)

    tmp_path =
      Path.join(
        System.tmp_dir!(),
        "export_#{:os.system_time(:second)}_#{System.unique_integer([:positive])}.zip"
      )

    File.touch!(tmp_path)
    on_exit(fn -> File.rm!(tmp_path) end)
    {:ok, fd} = File.open(tmp_path, [:binary, :raw, :append])

    populate_stats(site, [
      build(:pageview,
        user_id: 123,
        hostname: "export.dummy.site",
        pathname: "/",
        timestamp: ~U[2023-10-20 20:00:00Z]
      ),
      build(:pageview,
        user_id: 123,
        hostname: "export.dummy.site",
        pathname: "/about",
        timestamp: ~U[2023-10-20 20:01:00Z]
      ),
      build(:pageview,
        user_id: 123,
        hostname: "export.dummy.site",
        pathname: "/signup",
        timestamp: ~U[2023-10-20 20:03:20Z]
      )
    ])

    queries = Plausible.Export.export_queries(site.id)

    raw_queries =
      Enum.map(queries, fn {name, query} ->
        {sql, params} = Plausible.ClickhouseRepo.to_sql(:all, query)
        {Atom.to_string(name) <> ".csv", sql, params}
      end)

    config = Plausible.ClickhouseRepo.config()
    {:ok, conn} = Ch.start_link(Keyword.put(config, :pool_size, 1))

    :ok =
      Plausible.Export.export_archive(
        conn,
        raw_queries,
        fn data -> :file.write(fd, data) end,
        format: "CSVWithNames",
        site_id: site.id
      )

    :ok = File.close(fd)

    assert {:ok, files} = :zip.unzip(to_charlist(tmp_path), cwd: System.tmp_dir!())
    on_exit(fn -> Enum.each(files, &File.rm!/1) end)

    assert files |> Enum.map(&Path.basename/1) |> Enum.sort() == [
             "browsers.csv",
             "devices.csv",
             "entry_pages.csv",
             "exit_pages.csv",
             "locations.csv",
             "metadata.json",
             "operating_systems.csv",
             "pages.csv",
             "sources.csv",
             "visitors.csv"
           ]

    read = fn file -> File.read!(Path.join(System.tmp_dir!(), file)) end
    read_csv = fn file -> NimbleCSV.RFC4180.parse_string(read.(file), skip_headers: false) end
    read_json = fn file -> Jason.decode!(read.(file)) end

    assert read_json.("metadata.json") == %{
             "format" => "CSVWithNames",
             "site_id" => site.id,
             "version" => "0"
           }

    assert read_csv.("browsers.csv") == [
             ["date", "browser", "visitors", "visits", "visit_duration", "bounces"],
             ["2023-10-20", "", "1", "1", "200", "0"]
           ]

    assert read_csv.("devices.csv") == [
             ["date", "device", "visitors", "visits", "visit_duration", "bounces"],
             ["2023-10-20", "", "1", "1", "200", "0"]
           ]

    assert read_csv.("entry_pages.csv") == [
             ["date", "entry_page", "visitors", "entrances", "visit_duration", "bounces"],
             ["2023-10-20", "/", "1", "1", "200", "0"]
           ]

    assert read_csv.("exit_pages.csv") == [
             ["date", "exit_page", "visitors", "exits"],
             ["2023-10-20", "/signup", "1", "1"]
           ]

    assert read_csv.("locations.csv") == [
             [
               "date",
               "country",
               "region",
               "city",
               "visitors",
               "visits",
               "visit_duration",
               "bounces"
             ],
             # TODO
             ["2023-10-20", <<0, 0>>, "-", "0", "1", "1", "200", "0"]
           ]

    assert read_csv.("operating_systems.csv") == [
             ["date", "operating_system", "visitors", "visits", "visit_duration", "bounces"],
             ["2023-10-20", "", "1", "1", "200", "0"]
           ]

    assert read_csv.("pages.csv") == [
             ["date", "path", "hostname", "time_on_page", "exits", "pageviews", "visitors"],
             ["2023-10-20", "/signup", "export.dummy.site", "0", "1", "1", "1"],
             ["2023-10-20", "/", "export.dummy.site", "60", "0", "1", "1"],
             ["2023-10-20", "/about", "export.dummy.site", "140", "0", "1", "1"]
           ]

    assert read_csv.("sources.csv") == [
             [
               "date",
               "source",
               "utm_campaign",
               "utm_content",
               "utm_term",
               "visitors",
               "visits",
               "visit_duration",
               "bounces"
             ],
             ["2023-10-20", "", "", "", "", "1", "1", "200", "0"]
           ]

    assert read_csv.("visitors.csv") == [
             ["date", "visitors", "pageviews", "bounces", "visits", "visit_duration"],
             ["2023-10-20", "1", "3", "0", "1", "200"]
           ]
  end
end
