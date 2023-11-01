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
        format: "CSVWithNames"
      )

    :ok = File.close(fd)

    assert {:ok, files} = :zip.unzip(to_charlist(tmp_path), cwd: System.tmp_dir!())
    on_exit(fn -> Enum.each(files, &File.rm!/1) end)

    assert Enum.map(files, &Path.basename/1) == [
             "sources.csv",
             "visitors.csv",
             "devices.csv",
             "browsers.csv",
             "entry_pages.csv",
             "exit_pages.csv",
             "locations.csv",
             "operating_systems.csv",
             "pages.csv"
           ]

    read_csv = fn file ->
      NimbleCSV.RFC4180.parse_string(File.read!(file), skip_headers: false)
    end

    assert read_csv.("sources.csv") == [
             [
               "date",
               "utm_source",
               "utm_campaign",
               "utm_content",
               "utm_term",
               "uniq(user_id)",
               "sum(sign)",
               "toUInt32(round(divide(sum(multiply(duration, sign)), sum(sign))))",
               "sum(multiply(is_bounce, sign))"
             ],
             ["2023-10-20", "", "", "", "", "1", "1", "200", "0"]
           ]
  end
end
