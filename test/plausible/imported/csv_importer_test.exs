defmodule Plausible.Imported.CSVImporterTest do
  use Plausible
  use Plausible.Repo
  use PlausibleWeb.ConnCase
  alias Plausible.Imported.{CSVImporter, SiteImport}
  require SiteImport

  doctest CSVImporter, import: true

  on_ee do
    @moduletag :minio
  end

  describe "new_import/3 and parse_args/1" do
    setup [:create_user, :create_new_site]

    test "parses job args properly", %{user: user, site: site} do
      tables = [
        "imported_browsers",
        "imported_devices",
        "imported_entry_pages",
        "imported_exit_pages",
        "imported_locations",
        "imported_operating_systems",
        "imported_pages",
        "imported_sources",
        "imported_visitors"
      ]

      start_date = "20231001"
      end_date = "20240102"

      uploads =
        Enum.map(tables, fn table ->
          filename = "#{table}_#{start_date}_#{end_date}.csv"

          on_ee do
            %{
              "filename" => filename,
              "s3_url" =>
                "https://bucket-name.s3.eu-north-1.amazonaws.com/#{site.id}/#{filename}-some-random-suffix"
            }
          else
            %{
              "filename" => filename,
              "local_path" => "/tmp/some-random-path"
            }
          end
        end)

      date_range = CSVImporter.date_range(uploads)

      assert {:ok, job} =
               CSVImporter.new_import(site, user,
                 start_date: date_range.first,
                 end_date: date_range.last,
                 uploads: uploads,
                 storage: on_ee(do: "s3", else: "local")
               )

      assert %Oban.Job{args: %{"import_id" => import_id, "uploads" => ^uploads} = args} =
               Repo.reload!(job)

      assert [
               %{
                 id: ^import_id,
                 source: :csv,
                 start_date: ~D[2023-10-01],
                 end_date: ~D[2024-01-02],
                 status: SiteImport.pending()
               }
             ] = Plausible.Imported.list_all_imports(site)

      assert CSVImporter.parse_args(args) == [
               uploads: uploads,
               storage: on_ee(do: "s3", else: "local")
             ]
    end
  end

  describe "import_data/2" do
    setup [:create_user, :create_new_site, :clean_buckets]

    @describetag :tmp_dir

    test "imports tables from S3", %{site: site, user: user} = ctx do
      _ = ctx

      csvs = [
        %{
          name: "imported_browsers_20211230_20211231.csv",
          body: """
          "date","browser","visitors","visits","visit_duration","bounces"
          "2021-12-30","Amazon Silk",2,2,0,2
          "2021-12-30","Chrome",31,32,329,29
          "2021-12-30","Edge",3,3,0,3
          "2021-12-30","Firefox",1,1,0,1
          "2021-12-30","Internet Explorer",1,1,0,1
          "2021-12-30","Mobile App",2,2,0,2
          "2021-12-30","Mobile App",4,4,0,4
          "2021-12-30","Mobile App",1,1,0,1
          "2021-12-30","Safari",32,36,0,36
          "2021-12-30","Samsung Internet",2,2,0,2
          "2021-12-30","UC Browser",1,1,0,1
          "2021-12-31","Chrome",24,25,75,23
          "2021-12-31","Edge",3,3,0,3
          "2021-12-31","Firefox",1,1,466,0
          "2021-12-31","Mobile App",4,5,0,5
          "2021-12-31","Mobile App",4,4,0,4
          "2021-12-31","Mobile App",1,1,85,0
          "2021-12-31","Safari",37,45,1957,42
          "2021-12-31","Samsung Internet",1,1,199,0
          """
        },
        %{
          name: "imported_devices_20211230_20220102.csv",
          body: """
          "date","device","visitors","visits","visit_duration","bounces"
          "2021-12-30","Desktop",25,28,75,27
          "2021-12-30","Mobile",49,51,254,49
          "2021-12-30","Tablet",6,6,0,6
          "2021-12-31","Desktop",20,26,496,24
          "2021-12-31","Mobile",50,54,1842,49
          "2021-12-31","Tablet",5,5,444,4
          "2022-01-01","Desktop",33,34,1117,32
          "2022-01-01","Mobile",55,60,306,54
          "2022-01-01","Tablet",8,8,419,7
          "2022-01-02","Desktop",28,28,86,26
          "2022-01-02","Mobile",66,73,2450,65
          "2022-01-02","Tablet",9,9,0,9
          """
        },
        %{
          name: "imported_entry_pages_20211230_20211231.csv",
          body: """
          "date","visitors","entrances","visit_duration","bounces","entry_page"
          "2021-12-30",6,6,0,6,"/14776416252794997127"
          "2021-12-30",1,1,0,1,"/15455127321321119046"
          "2021-12-30",1,1,43,0,"/10399835914295020763"
          "2021-12-30",1,1,0,1,"/9102354072466236765"
          "2021-12-30",1,1,0,1,"/1586391735863371077"
          "2021-12-30",1,1,0,1,"/3457026921000639206"
          "2021-12-30",2,3,0,3,"/6077502147861556415"
          "2021-12-30",1,1,0,1,"/14280570555317344651"
          "2021-12-30",3,3,0,3,"/5284268072698982201"
          "2021-12-30",1,1,0,1,"/7478911940502018071"
          "2021-12-30",1,1,0,1,"/6402607186523575652"
          "2021-12-30",2,2,0,2,"/9962503789684934900"
          "2021-12-30",8,10,0,10,"/13595620304963848161"
          "2021-12-30",2,2,0,2,"/17019199732013993436"
          "2021-12-30",31,31,211,30,"/9874837495456455794"
          "2021-12-31",4,4,0,4,"/14776416252794997127"
          "2021-12-31",1,1,0,1,"/8738789417178304429"
          "2021-12-31",1,1,0,1,"/7445073500314667742"
          "2021-12-31",1,1,0,1,"/4897404798407749335"
          "2021-12-31",1,1,45,0,"/11263893625781431659"
          "2021-12-31",1,1,0,1,"/16478773157730928089"
          "2021-12-31",1,1,0,1,"/1710995203264225236"
          "2021-12-31",1,1,0,1,"/14280570555317344651"
          "2021-12-31",4,5,444,4,"/5284268072698982201"
          "2021-12-31",2,2,466,1,"/7478911940502018071"
          "2021-12-31",9,16,1455,15,"/13595620304963848161"
          "2021-12-31",25,25,88,23,"/9874837495456455794"
          """
        },
        %{
          name: "imported_exit_pages_20211230_20211231.csv",
          body: """
          "date","visitors","exits","exit_page"
          "2021-12-30",6,6,"/14776416252794997127"
          "2021-12-30",1,1,"/15455127321321119046"
          "2021-12-30",1,1,"/9102354072466236765"
          "2021-12-30",1,1,"/4457889102355683190"
          "2021-12-30",1,1,"/12105301321223776356"
          "2021-12-30",1,2,"/1526239929864936398"
          "2021-12-30",1,1,"/7478911940502018071"
          "2021-12-30",1,1,"/6402607186523575652"
          "2021-12-30",2,2,"/9962503789684934900"
          "2021-12-30",8,10,"/13595620304963848161"
          "2021-12-30",2,2,"/17019199732013993436"
          "2021-12-30",32,32,"/9874837495456455794"
          "2021-12-31",4,4,"/14776416252794997127"
          "2021-12-31",1,1,"/8738789417178304429"
          "2021-12-31",1,1,"/7445073500314667742"
          "2021-12-31",1,1,"/4897404798407749335"
          "2021-12-31",1,1,"/11263893625781431659"
          "2021-12-31",1,1,"/16478773157730928089"
          "2021-12-31",1,1,"/1710995203264225236"
          """
        },
        %{
          name: "imported_locations_20211230_20211231.csv",
          body: """
          "date","country","region","city","visitors","visits","visit_duration","bounces"
          "2021-12-30","AU","",0,1,1,43,0
          "2021-12-30","AU","",2078025,3,4,211,3
          "2021-12-30","AU","",2147714,2,2,0,2
          "2021-12-30","AU","",2158177,2,2,0,2
          "2021-12-30","AU","",2174003,1,1,0,1
          "2021-12-30","BE","",0,1,1,0,1
          "2021-12-30","BE","",2792196,1,1,0,1
          "2021-12-30","BR","",0,1,1,0,1
          "2021-12-30","CA","",0,1,1,0,1
          "2021-12-30","PL","",0,1,1,0,1
          "2021-12-30","PL","",756135,1,1,0,1
          "2021-12-30","US","",0,1,1,0,1
          "2021-12-30","US","",0,1,1,0,1
          "2021-12-30","US","",0,1,1,0,1
          "2021-12-30","US","",0,1,1,0,1
          "2021-12-30","US","",4063926,1,1,0,1
          "2021-12-30","US","",4074013,1,3,0,3
          "2021-12-30","US","",5089478,1,1,0,1
          "2021-12-31","AU","",2147714,3,3,0,3
          "2021-12-31","AU","",2158177,2,2,0,2
          "2021-12-31","CA","",0,1,1,0,1
          "2021-12-31","IT","",3176959,1,1,85,0
          "2021-12-31","KR","",1835848,1,1,0,1
          "2021-12-31","LV","",456172,1,1,0,1
          "2021-12-31","MX","",3530757,2,3,0,3
          "2021-12-31","NL","",0,1,1,0,1
          "2021-12-31","NL","",0,1,2,0,2
          "2021-12-31","NL","",2745321,1,1,0,1
          "2021-12-31","NO","",0,1,1,199,0
          "2021-12-31","SE","",0,1,1,0,1
          "2021-12-31","SG","",1880252,1,1,0,1
          """
        },
        %{
          name: "imported_operating_systems_20211230_20220101.csv",
          body: """
          "date","operating_system","visitors","visits","visit_duration","bounces"
          "2021-12-30","Android",25,26,254,24
          "2021-12-30","Mac",13,16,0,16
          "2021-12-30","Windows",12,12,75,11
          "2021-12-30","iOS",30,31,0,31
          "2021-12-31","Android",15,16,329,13
          "2021-12-31","Mac",13,19,0,19
          "2021-12-31","Windows",7,7,496,5
          "2021-12-31","iOS",40,43,1957,40
          "2022-01-01","",17,18,0,18
          "2022-01-01","Android",25,28,32,26
          "2022-01-01","Chrome OS",1,1,0,1
          "2022-01-01","Mac",6,6,0,6
          "2022-01-01","Windows",9,9,1117,7
          "2022-01-01","iOS",38,40,693,35
          """
        },
        %{
          name: "imported_pages_20211230_20220101.csv",
          body: """
          "date","visitors","pageviews","hostname","page"
          "2021-12-30",1,1,"lucky.numbers.com","/14776416252794997127"
          "2021-12-30",1,1,"lucky.numbers.com","/14776416252794997127"
          "2021-12-30",6,6,"lucky.numbers.com","/14776416252794997127"
          "2021-12-30",1,1,"lucky.numbers.com","/9102354072466236765"
          "2021-12-30",1,1,"lucky.numbers.com","/7478911940502018071"
          "2021-12-30",1,1,"lucky.numbers.com","/6402607186523575652"
          "2021-12-30",2,2,"lucky.numbers.com","/9962503789684934900"
          "2021-12-30",8,10,"lucky.numbers.com","/13595620304963848161"
          "2021-12-30",2,2,"lucky.numbers.com","/17019199732013993436"
          "2021-12-30",32,33,"lucky.numbers.com","/9874837495456455794"
          "2021-12-31",4,4,"lucky.numbers.com","/14776416252794997127"
          "2021-12-31",1,1,"lucky.numbers.com","/8738789417178304429"
          "2021-12-31",1,1,"lucky.numbers.com","/7445073500314667742"
          "2021-12-31",1,1,"lucky.numbers.com","/4897404798407749335"
          "2021-12-31",1,2,"lucky.numbers.com","/11263893625781431659"
          "2022-01-01",2,2,"lucky.numbers.com","/5878724061840196349"
          """
        },
        %{
          name: "imported_sources_20211230_20220106.csv",
          body: """
          "date","source","utm_medium","utm_campaign","utm_content","utm_term","visitors","visits","visit_duration","bounces"
          "2021-12-30","","","","","",25,26,254,24
          "2021-12-30","Hacker News","referral","","","",2,2,0,2
          "2021-12-30","Google","organic","","","",20,22,75,21
          "2021-12-30","Pinterest","referral","","","",25,26,0,26
          "2021-12-30","baidu","organic","","","",1,1,0,1
          "2021-12-30","yahoo","organic","","","",3,3,0,3
          "2021-12-31","","","","","",16,16,199,15
          "2021-12-31","Bing","organic","","","",1,1,0,1
          "2021-12-31","DuckDuckGo","organic","","","",1,1,0,1
          "2021-12-31","Hacker News","referral","","","",1,1,466,0
          "2021-12-31","Google","organic","","","",25,32,85,31
          "2021-12-31","Pinterest","referral","","","",22,24,88,22
          "2021-12-31","yahoo","organic","","","",3,3,1899,1
          "2022-01-01","","","","","",37,38,1137,35
          "2022-01-01","Bing","organic","","","",2,2,171,1
          "2022-01-01","DuckDuckGo","organic","","","",2,3,0,3
          "2022-01-01","Hacker News","referral","","","",1,1,0,1
          "2022-01-01","Google","referral","","","",1,1,0,1
          "2022-01-01","Google","organic","","","",21,23,115,19
          "2022-01-01","Pinterest","referral","","","",29,30,0,30
          "2022-01-01","yahoo","organic","","","",3,3,419,2
          "2022-01-06","","","","","",37,38,430,36
          "2022-01-06","Bing","organic","","","how lucky am I as UInt64",1,1,0,1
          "2022-01-06","Bing","organic","","","",3,3,10,2
          """
        },
        %{
          name: "imported_visitors_20111225_20111230.csv",
          body: """
          "date","visitors","pageviews","bounces","visits","visit_duration"
          "2011-12-25",5,50,2,7,8640
          "2011-12-26",3,4,2,3,43
          "2011-12-27",3,6,2,4,2313
          "2011-12-28",6,30,4,8,2264
          "2011-12-29",4,8,5,6,136
          "2011-12-30",1,1,1,1,0
          """
        }
      ]

      uploads =
        for %{name: name, body: body} <- csvs do
          on_ee do
            %{s3_url: s3_url} = Plausible.S3.import_presign_upload(site.id, name)
            [bucket, key] = String.split(URI.parse(s3_url).path, "/", parts: 2)
            ExAws.request!(ExAws.S3.put_object(bucket, key, body))
            %{"filename" => name, "s3_url" => s3_url}
          else
            local_path = Path.join(ctx.tmp_dir, name)
            File.write!(local_path, body)
            %{"filename" => name, "local_path" => local_path}
          end
        end

      date_range = CSVImporter.date_range(uploads)

      {:ok, _job} =
        CSVImporter.new_import(site, user,
          start_date: date_range.first,
          end_date: date_range.last,
          uploads: uploads,
          storage: on_ee(do: "s3", else: "local")
        )

      assert %{success: 1} = Oban.drain_queue(queue: :analytics_imports, with_safety?: false)

      assert %SiteImport{
               start_date: ~D[2011-12-25],
               end_date: ~D[2022-01-06],
               source: :csv,
               status: :completed
             } = Repo.get_by!(SiteImport, site_id: site.id)

      assert Plausible.Stats.Clickhouse.imported_pageview_count(site) == 99
    end

    test "fails on invalid CSV", %{site: site, user: user} = ctx do
      _ = ctx

      csvs = [
        %{
          name: "imported_browsers_20211230_20211231.csv",
          body: """
          "date","browser","visitors","visits","visit_duration","bounces"
          "2021-12-30","Amazon Silk",2,2,0,2
          "2021-12-30","Chrome",31,32,329,29
          "2021-12-30","Edge",3,3,0,3
          "2021-12-30","Firefox",1,1,0,1
          "2021-12-30","Internet Explorer",1,1,0,1
          "2021-12-30","Mobile App",2,2,0,2
          "2021-12-31","Mobile App",4,4,0,4
          """
        },
        %{
          name: "imported_devices_20211230_20211231.csv",
          body: """
          "date","device","visitors","visit_duration","bounces"
          "2021-12-30","Desktop",28,ehhhh....
          """
        }
      ]

      uploads =
        for %{name: name, body: body} <- csvs do
          on_ee do
            %{s3_url: s3_url} = Plausible.S3.import_presign_upload(site.id, name)
            [bucket, key] = String.split(URI.parse(s3_url).path, "/", parts: 2)
            ExAws.request!(ExAws.S3.put_object(bucket, key, body))
            %{"filename" => name, "s3_url" => s3_url}
          else
            local_path = Path.join(ctx.tmp_dir, name)
            File.write!(local_path, body)
            %{"filename" => name, "local_path" => local_path}
          end
        end

      date_range = CSVImporter.date_range(uploads)

      {:ok, _job} =
        CSVImporter.new_import(site, user,
          start_date: date_range.first,
          end_date: date_range.last,
          uploads: uploads,
          storage: on_ee(do: "s3", else: "local")
        )

      assert %{discard: 1} = Oban.drain_queue(queue: :analytics_imports, with_safety?: false)

      # TODO
      # assert {:discard, message} = Plausible.Workers.ImportAnalytics.perform(job)
      # assert message =~ "CANNOT_PARSE_INPUT_ASSERTION_FAILED"

      assert %SiteImport{id: import_id, source: :csv, status: :failed} =
               Repo.get_by!(SiteImport, site_id: site.id)

      # ensure no browser left behind
      imported_browsers_q = from b in "imported_browsers", where: b.import_id == ^import_id
      assert await_clickhouse_count(imported_browsers_q, 0)
    end
  end

  describe "export -> import" do
    setup [:create_user, :log_in, :create_api_key, :use_api_key, :clean_buckets]

    @tag :tmp_dir
    test "it works", %{conn: conn, user: user, tmp_dir: tmp_dir} do
      exported_site = insert(:site, members: [user])
      imported_site = insert(:site, members: [user])

      process_csv = fn path ->
        [header | rows] = NimbleCSV.RFC4180.parse_string(File.read!(path), skip_headers: false)

        site_id_column_index =
          Enum.find_index(header, &(&1 == "site_id")) ||
            raise "couldn't find site_id column in CSV header #{inspect(header)}"

        rows =
          Enum.map(rows, fn row ->
            List.replace_at(row, site_id_column_index, exported_site.id)
          end)

        NimbleCSV.RFC4180.dump_to_iodata([header | rows])
      end

      Plausible.IngestRepo.query!([
        "insert into events_v2 format CSVWithNames\n",
        process_csv.("fixture/plausible_io_events_v2_2024_03_01_2024_03_31_500users_dump.csv")
      ])

      Plausible.IngestRepo.query!([
        "insert into sessions_v2 format CSVWithNames\n",
        process_csv.("fixture/plausible_io_sessions_v2_2024_03_01_2024_03_31_500users_dump.csv")
      ])

      # export archive to s3
      on_ee do
        assert {:ok, _job} = Plausible.Exports.schedule_s3_export(exported_site.id, user.email)
      else
        assert {:ok, %{args: %{"local_path" => local_path}}} =
                 Plausible.Exports.schedule_local_export(exported_site.id, user.email)
      end

      assert %{success: 1} = Oban.drain_queue(queue: :analytics_exports, with_safety: false)

      # download archive
      on_ee do
        ExAws.request!(
          ExAws.S3.download_file(
            Plausible.S3.exports_bucket(),
            to_string(exported_site.id),
            Path.join(tmp_dir, "plausible-export.zip")
          )
        )
      else
        File.rename!(local_path, Path.join(tmp_dir, "plausible-export.zip"))
      end

      # unzip archive
      {:ok, files} =
        :zip.unzip(to_charlist(Path.join(tmp_dir, "plausible-export.zip")), cwd: tmp_dir)

      # upload csvs
      uploads =
        Enum.map(files, fn file ->
          on_ee do
            %{s3_url: s3_url} = Plausible.S3.import_presign_upload(imported_site.id, file)
            [bucket, key] = String.split(URI.parse(s3_url).path, "/", parts: 2)
            ExAws.request!(ExAws.S3.put_object(bucket, key, File.read!(file)))
            %{"filename" => Path.basename(file), "s3_url" => s3_url}
          else
            %{"filename" => Path.basename(file), "local_path" => file}
          end
        end)

      # run importer
      date_range = CSVImporter.date_range(uploads)

      {:ok, _job} =
        CSVImporter.new_import(imported_site, user,
          start_date: date_range.first,
          end_date: date_range.last,
          uploads: uploads,
          storage: on_ee(do: "s3", else: "local")
        )

      assert %{success: 1} = Oban.drain_queue(queue: :analytics_imports, with_safety: false)

      # validate import
      assert %SiteImport{
               start_date: ~D[2024-03-28],
               end_date: ~D[2024-03-31],
               source: :csv,
               status: :completed
             } = Repo.get_by!(SiteImport, site_id: imported_site.id)

      assert Plausible.Stats.Clickhouse.imported_pageview_count(exported_site) == 0
      assert Plausible.Stats.Clickhouse.imported_pageview_count(imported_site) == 12250

      # compare original and imported data via stats api requests
      results = fn path, params ->
        get(conn, path, params)
        |> json_response(200)
        |> Map.fetch!("results")
      end

      timeseries = fn params ->
        results.("/api/v1/stats/timeseries", params)
      end

      common_params = fn site ->
        %{
          "site_id" => site.domain,
          "period" => "custom",
          "date" => "2024-03-28,2024-03-31",
          "with_imported" => true
        }
      end

      breakdown = fn params_or_site, by ->
        params =
          case params_or_site do
            %Plausible.Site{} = site ->
              common_params.(site)
              |> Map.put("metrics", "visitors,visits,pageviews,visit_duration,bounce_rate")
              |> Map.put("limit", 1000)
              |> Map.put("property", "visit:#{by}")

            params ->
              params
          end

        Enum.sort_by(results.("/api/v1/stats/breakdown", params), &Map.fetch!(&1, by))
      end

      # timeseries
      timeseries_params = fn site ->
        Map.put(
          common_params.(site),
          "metrics",
          "visitors,visits,pageviews,views_per_visit,visit_duration,bounce_rate"
        )
      end

      exported_timeseries = timeseries.(timeseries_params.(exported_site))
      imported_timeseries = timeseries.(timeseries_params.(imported_site))

      pairwise(exported_timeseries, imported_timeseries, fn exported, imported ->
        assert exported["date"] == imported["date"]
        assert exported["pageviews"] == imported["pageviews"]
      end)

      # timeseries' views per visit shows too much difference between original and export->import timeseries
      # NOTE: at worst, it's 2.5x the original
      assert summary(field(exported_timeseries, "views_per_visit")) == [
               2.98,
               2.995,
               3.065,
               3.135,
               3.15
             ]

      assert summary(field(imported_timeseries, "views_per_visit")) == [
               4.53,
               6.3225,
               7.390000000000001,
               7.9325,
               8.15
             ]

      assert summary(
               pairwise(exported_timeseries, imported_timeseries, fn exported, imported ->
                 abs(1 - imported["views_per_visit"] / exported["views_per_visit"])
               end)
             ) == [
               0.5201342281879195,
               1.11003355704698,
               1.4089243876464324,
               1.5302119782950454,
               1.5873015873015874
             ]

      # timeseries' bounce rate difference is within 3%
      assert summary(field(exported_timeseries, "bounce_rate")) == [36, 37.5, 39, 41.25, 45]
      assert summary(field(imported_timeseries, "bounce_rate")) == [37, 37.75, 38.5, 40.5, 45]

      assert summary(
               pairwise(exported_timeseries, imported_timeseries, fn exported, imported ->
                 abs(1 - exported["bounce_rate"] / imported["bounce_rate"])
               end)
             ) == [0, 0, 0.012820512820512775, 0.025987525987525906, 0.027027027027026973]

      # timeseries' visit duration difference is within 4%
      assert summary(field(exported_timeseries, "visit_duration")) == [
               457,
               549.25,
               588,
               610.5,
               654
             ]

      assert summary(field(imported_timeseries, "visit_duration")) == [
               449.9,
               549.875,
               589.9000000000001,
               617.55,
               680.4
             ]

      assert summary(
               pairwise(exported_timeseries, imported_timeseries, fn exported, imported ->
                 abs(1 - exported["visit_duration"] / imported["visit_duration"])
               end)
             ) == [
               0.015781284729940115,
               0.020406226532279248,
               0.024886105857288232,
               0.030568429802981162,
               0.03880070546737213
             ]

      # timeseries' visitors difference is within 3%
      assert summary(field(exported_timeseries, "visitors")) == [80, 88.25, 93.5, 197, 500]
      assert summary(field(imported_timeseries, "visitors")) == [78, 87, 92, 194.75, 497]

      assert summary(
               pairwise(exported_timeseries, imported_timeseries, fn exported, imported ->
                 abs(1 - exported["visitors"] / imported["visitors"])
               end)
             ) == [
               0.006036217303822866,
               0.00984238765928902,
               0.01619385342789592,
               0.022367703218766966,
               0.02564102564102555
             ]

      # timeseries' visits difference is within 2%
      assert summary(field(exported_timeseries, "visits")) == [250, 289.75, 314.5, 546.5, 1208]
      assert summary(field(imported_timeseries, "visits")) == [253, 293.5, 315, 543.25, 1204]

      assert summary(
               pairwise(exported_timeseries, imported_timeseries, fn exported, imported ->
                 abs(1 - exported["visits"] / imported["visits"])
               end)
             ) == [
               0.0033222591362125353,
               0.007796509056499035,
               0.010572816603238,
               0.012150609622639114,
               0.013029315960912058
             ]

      # pages
      pages_params = fn site ->
        common_params.(site)
        |> Map.put("metrics", "visitors,visits,pageviews,time_on_page,visit_duration,bounce_rate")
        |> Map.put("limit", 1000)
        |> Map.put("property", "event:page")
      end

      exported_pages = breakdown.(pages_params.(exported_site), "page")
      imported_pages = breakdown.(pages_params.(imported_site), "page")

      pairwise(exported_pages, imported_pages, fn exported, imported ->
        assert exported["page"] == imported["page"]
        assert exported["pageviews"] == imported["pageviews"]
        assert exported["bounce_rate"] == imported["bounce_rate"]

        # time on page is not being exported/imported right now
        assert imported["time_on_page"] == 0
      end)

      # page breakdown's visit_duration difference is within 1%
      assert summary(field(exported_pages, "visit_duration")) == [0, 0, 25, 217.5, 743]
      assert summary(field(imported_pages, "visit_duration")) == [0, 0, 25, 217.55, 742.8]

      assert summary(
               pairwise(exported_pages, imported_pages, fn exported, imported ->
                 e = exported["visit_duration"]
                 i = imported["visit_duration"]

                 if is_number(e) and is_number(i) and i > 0 do
                   abs(1 - e / i)
                 else
                   # both nil or both zero
                   assert e == i
                   _no_diff = 0
                 end
               end)
             ) == [0, 0, 0, 0, 0.002375296912114022]

      # NOTE: page breakdown's visitors difference is up to almost 37%
      assert summary(field(exported_pages, "visitors")) == [1, 1, 2, 2.5, 396]
      assert summary(field(imported_pages, "visitors")) == [1, 1, 2, 2.5, 626]

      assert summary(
               pairwise(exported_pages, imported_pages, fn exported, imported ->
                 e = exported["visitors"]
                 i = imported["visitors"]

                 # only consider non tiny readings
                 if abs(e - i) > 5, do: abs(1 - e / i), else: 0
               end)
             ) == [0, 0, 0, 0, 0.36741214057507987]

      # page breakdown's visits difference is within 1%
      assert summary(field(exported_pages, "visits")) == [1, 1, 2, 3, 1785]
      assert summary(field(imported_pages, "visits")) == [1, 1, 2, 2.5, 1794]

      assert summary(
               pairwise(exported_pages, imported_pages, fn exported, imported ->
                 e = exported["visits"]
                 i = imported["visits"]

                 # only consider non tiny readings
                 if abs(e - i) > 5, do: abs(1 - e / i), else: 0
               end)
             ) == [0, 0, 0, 0, 0.0050167224080267525]

      # sources
      exported_sources = breakdown.(exported_site, "source")
      imported_sources = breakdown.(imported_site, "source")

      pairwise(exported_sources, imported_sources, fn exported, imported ->
        assert exported["source"] == imported["source"]
        assert exported["bounce_rate"] == imported["bounce_rate"]
        assert exported["visits"] == imported["visits"]
      end)

      # source breakdown's visit_duration difference is within 1%
      assert summary(field(exported_sources, "visit_duration")) == [0, 0, 0, 27, 534]
      assert summary(field(imported_sources, "visit_duration")) == [0, 0, 0, 27, 534.5]

      assert summary(
               pairwise(exported_sources, imported_sources, fn exported, imported ->
                 e = exported["visit_duration"]
                 i = imported["visit_duration"]

                 if is_number(e) and is_number(i) and i > 0 do
                   abs(1 - e / i)
                 else
                   # both nil or both 0
                   assert e == i
                   _no_diff = 0
                 end
               end)
             ) == [0, 0, 0, 0, 0.001335113484646211]

      # NOTE: source breakdown's pageviews difference up to almost 50%
      assert summary(field(exported_sources, "pageviews")) == [1, 1, 1, 3, 6210]
      assert summary(field(imported_sources, "pageviews")) == [1, 1, 1, 3, 12135]

      assert Enum.max(
               pairwise(exported_sources, imported_sources, fn exported, imported ->
                 e = exported["pageviews"]
                 i = imported["pageviews"]

                 # only consider non tiny readings
                 if abs(e - i) > 10, do: abs(1 - e / i), else: 0
               end)
             ) == 0.48825710754017304

      # NOTE: source breakdown's visitors difference up to almost 40%
      assert summary(field(exported_sources, "visitors")) == [1, 1, 1, 2, 451]
      assert summary(field(imported_sources, "visitors")) == [1, 1, 1, 2, 712]

      assert Enum.max(
               pairwise(exported_sources, imported_sources, fn exported, imported ->
                 abs(1 - exported["visitors"] / imported["visitors"])
               end)
             ) == 0.3665730337078652

      # utm mediums
      assert breakdown.(exported_site, "utm_medium") == breakdown.(imported_site, "utm_medium")

      # entry pages
      exported_entry_pages = breakdown.(exported_site, "entry_page")
      imported_entry_pages = breakdown.(imported_site, "entry_page")

      pairwise(exported_entry_pages, imported_entry_pages, fn exported, imported ->
        assert exported["entry_page"] == imported["entry_page"]
        assert exported["bounce_rate"] == imported["bounce_rate"]
        assert exported["visits"] == imported["visits"]
      end)

      # entry page breakdown's visit_duration difference is within 1%
      assert summary(field(exported_entry_pages, "visit_duration")) == [0, 0, 25, 217.5, 743]
      assert summary(field(imported_entry_pages, "visit_duration")) == [0, 0, 25, 217.55, 742.8]

      assert Enum.max(
               pairwise(exported_entry_pages, imported_entry_pages, fn exported, imported ->
                 e = exported["visit_duration"]
                 i = imported["visit_duration"]

                 if is_number(e) and is_number(i) and i > 0 do
                   abs(1 - e / i)
                 else
                   # both nil or both 0
                   assert e == i
                   _no_diff = 0
                 end
               end)
             ) == 0.002375296912114022

      # NOTE: entry page breakdown's pageviews difference up to almost 130%
      assert summary(field(exported_entry_pages, "pageviews")) == [1, 1, 2.5, 9.75, 3795]
      assert summary(field(imported_entry_pages, "pageviews")) == [1, 1, 2, 9, 10366]

      assert Enum.max(
               pairwise(exported_entry_pages, imported_entry_pages, fn exported, imported ->
                 e = exported["pageviews"]
                 i = imported["pageviews"]

                 # only consider non tiny readings
                 if abs(e - i) > 100, do: abs(1 - e / i), else: 0
               end)
             ) == 1.237704918032787

      # NOTE: entry page breakdown's visitors difference up to almost 50%
      assert summary(field(exported_entry_pages, "visitors")) == [1, 1, 1, 2, 310]
      assert summary(field(imported_entry_pages, "visitors")) == [1, 1, 1, 2, 476]

      assert Enum.max(
               pairwise(exported_entry_pages, imported_entry_pages, fn exported, imported ->
                 abs(1 - exported["visitors"] / imported["visitors"])
               end)
             ) == 0.5

      # cities
      exported_cities = breakdown.(exported_site, "city")
      imported_cities = breakdown.(imported_site, "city")

      pairwise(exported_cities, imported_cities, fn exported, imported ->
        assert exported["city"] == imported["city"]
      end)

      # city breakdown's bounce_rate difference is within 5
      assert summary(field(exported_cities, "bounce_rate")) == [0, 17, 50, 100, 100]
      assert summary(field(imported_cities, "bounce_rate")) == [0, 17, 50, 100, 100]

      pairwise(exported_cities, imported_cities, fn exported, imported ->
        e = exported["bounce_rate"]
        i = imported["bounce_rate"]

        if is_number(e) and is_number(i) do
          assert_in_delta e, i, 5
        else
          assert e == i
        end
      end)

      # city breakdown's visits difference is within 1
      assert summary(field(exported_cities, "visits")) == [1, 1, 3, 7, 63]
      assert summary(field(imported_cities, "visits")) == [1, 1, 3, 7, 63]

      pairwise(exported_cities, imported_cities, fn exported, imported ->
        e = exported["visits"]
        i = imported["visits"]

        if is_number(e) and is_number(i) do
          assert_in_delta e, i, 1
        else
          assert e == i
        end
      end)

      # NOTE: city breakdown's visit_duration difference is up to almost 240%
      assert summary(field(exported_cities, "visit_duration")) == [0, 0, 49, 359, 7324]

      assert summary(field(imported_cities, "visit_duration")) == [
               0,
               0,
               47.650000000000006,
               358.70000000000005,
               7324
             ]

      assert Enum.max(
               pairwise(exported_cities, imported_cities, fn exported, imported ->
                 e = exported["visit_duration"]
                 i = imported["visit_duration"]

                 if is_number(e) and is_number(i) and i > 0 do
                   # only consider non tiny readings
                   if abs(e - i) > 10, do: abs(1 - e / i), else: 0
                 else
                   # both nil or both 0
                   assert e == i
                   _no_diff = 0
                 end
               end)
             ) == 2.3817427385892116

      # NOTE: city breakdown's pageviews difference up to almost 80%
      assert summary(field(exported_cities, "pageviews")) == [1, 2, 6, 16.25, 383]
      assert summary(field(imported_cities, "pageviews")) == [1, 2, 6, 16.25, 454]

      assert Enum.max(
               pairwise(exported_cities, imported_cities, fn exported, imported ->
                 abs(1 - exported["pageviews"] / imported["pageviews"])
               end)
             ) == 0.7687224669603524

      # NOTE: city breakdown's visitors difference up to almost 70%
      assert summary(field(exported_cities, "visitors")) == [1, 1, 1, 1, 7]
      assert summary(field(imported_cities, "visitors")) == [1, 1, 1, 3, 13]

      assert Enum.max(
               pairwise(exported_cities, imported_cities, fn exported, imported ->
                 e = exported["visitors"]
                 i = imported["visitors"]

                 # only consider non tiny readings
                 if abs(e - i) > 3, do: abs(1 - e / i), else: 0
               end)
             ) == 0.6666666666666667

      # devices
      exported_devices = breakdown.(exported_site, "device")
      imported_devices = breakdown.(imported_site, "device")

      pairwise(exported_devices, imported_devices, fn exported, imported ->
        assert exported["device"] == imported["device"]
        assert exported["bounce_rate"] == imported["bounce_rate"]
        assert exported["visits"] == imported["visits"]
      end)

      # device breakdown's visit_duration difference is within 1%
      assert summary(field(exported_devices, "visit_duration")) == [
               470,
               492.75,
               515.5,
               538.25,
               561
             ]

      assert summary(field(imported_devices, "visit_duration")) == [
               469.9,
               492.575,
               515.25,
               537.925,
               560.6
             ]

      assert Enum.max(
               pairwise(exported_devices, imported_devices, fn exported, imported ->
                 abs(1 - exported["visit_duration"] / imported["visit_duration"])
               end)
             ) == 0.0007135212272564306

      # NOTE: device breakdown's pageviews difference up to 60%
      assert summary(field(exported_devices, "pageviews")) == [
               2407,
               2784.75,
               3162.5,
               3540.25,
               3918
             ]

      assert summary(field(imported_devices, "pageviews")) == [2414, 4269.5, 6125.0, 7980.5, 9836]

      assert Enum.max(
               pairwise(exported_devices, imported_devices, fn exported, imported ->
                 abs(1 - exported["pageviews"] / imported["pageviews"])
               end)
             ) == 0.601667344448963

      # NOTE: device breakdown's visitors difference up to almost 40%
      assert summary(field(exported_devices, "visitors")) == [216, 232.25, 248.5, 264.75, 281]
      assert summary(field(imported_devices, "visitors")) == [304, 341.75, 379.5, 417.25, 455]

      assert Enum.max(
               pairwise(exported_devices, imported_devices, fn exported, imported ->
                 abs(1 - exported["visitors"] / imported["visitors"])
               end)
             ) == 0.3824175824175824

      # browsers
      exported_browsers = breakdown.(exported_site, "browser")
      imported_browsers = breakdown.(imported_site, "browser")

      pairwise(exported_browsers, imported_browsers, fn exported, imported ->
        assert exported["browser"] == imported["browser"]
        assert exported["bounce_rate"] == imported["bounce_rate"]
        assert exported["visits"] == imported["visits"]
      end)

      # browser breakdown's visit_duration difference is within 1%
      assert summary(field(exported_browsers, "visit_duration")) == [2, 144.5, 250, 530.5, 565]
      assert summary(field(imported_browsers, "visit_duration")) == [2, 144.55, 249.6, 530.3, 565]

      assert Enum.max(
               pairwise(exported_browsers, imported_browsers, fn exported, imported ->
                 abs(1 - exported["visit_duration"] / imported["visit_duration"])
               end)
             ) == 0.0016025641025640969

      # NOTE: browser breakdown's pageviews difference up to 60%
      assert summary(field(exported_browsers, "pageviews")) == [4, 15.5, 140, 1337, 3476]
      assert summary(field(imported_browsers, "pageviews")) == [4, 15.5, 140, 1339, 9128]

      assert Enum.max(
               pairwise(exported_browsers, imported_browsers, fn exported, imported ->
                 e = exported["pageviews"]
                 i = imported["pageviews"]

                 # only consider non tiny readings
                 if abs(e - i) > 100, do: abs(1 - e / i), else: 0
               end)
             ) == 0.619193689745837

      # NOTE: browser breakdown's visitors difference up to almost 70%
      assert summary(field(exported_browsers, "visitors")) == [1, 1, 10, 105, 274]
      assert summary(field(imported_browsers, "visitors")) == [1, 2, 18, 157, 422]

      assert Enum.max(
               pairwise(exported_browsers, imported_browsers, fn exported, imported ->
                 abs(1 - exported["visitors"] / imported["visitors"])
               end)
             ) == 0.6666666666666667

      # # os
      # exported_os = breakdown.(exported_site, "os")
      # imported_os = breakdown.(imported_site, "os")

      # pairwise(exported_os, imported_os, fn exported, imported ->
      #   assert exported["os"] == imported["os"]

      #   assert_field_in_delta(exported, imported, "pageviews", 0.0000001)
      #   assert_field_in_delta(exported, imported, "bounce_rate", 0.0000001)
      #   assert_field_in_delta(exported, imported, "visit_duration", 0.0000001)
      #   assert_field_in_delta(exported, imported, "visitors", 0.0000001)
      #   assert_field_in_delta(exported, imported, "visits", 0.0000001)
      # end)

      # # os versions
      # exported_os_versions = breakdown.(exported_site, "os_version")
      # imported_os_versions = breakdown.(imported_site, "os_version")

      # pairwise(exported_os_versions, imported_os_versions, fn exported, imported ->
      #   assert exported["os_version"] == imported["os_version"]

      #   assert_field_in_delta(exported, imported, "pageviews", 0.0000001)
      #   assert_field_in_delta(exported, imported, "bounce_rate", 0.0000001)
      #   assert_field_in_delta(exported, imported, "visit_duration", 0.0000001)
      #   assert_field_in_delta(exported, imported, "visitors", 0.0000001)
      #   assert_field_in_delta(exported, imported, "visits", 0.0000001)
      # end)
    end
  end

  defp clean_buckets(_context) do
    on_ee do
      clean_bucket = fn bucket ->
        ExAws.S3.list_objects_v2(bucket)
        |> ExAws.stream!()
        |> Stream.each(fn objects ->
          keys = objects |> List.wrap() |> Enum.map(& &1.key)
          ExAws.request!(ExAws.S3.delete_all_objects(bucket, keys))
        end)
        |> Stream.run()
      end

      clean_bucket.(Plausible.S3.imports_bucket())
      clean_bucket.(Plausible.S3.exports_bucket())

      on_exit(fn ->
        clean_bucket.(Plausible.S3.imports_bucket())
        clean_bucket.(Plausible.S3.exports_bucket())
      end)
    else
      :ok
    end
  end

  defp pairwise(left, right, f) do
    assert length(left) == length(right)
    zipped = Enum.zip(left, right)
    Enum.map(zipped, fn {left, right} -> f.(left, right) end)
  end

  defp field(results, field) do
    results
    |> Enum.map(&Map.fetch!(&1, field))
    |> Enum.filter(&is_number/1)
  end

  defp summary(values) do
    values = Enum.sort(values)

    percentile = fn n ->
      r = n / 100.0 * (length(values) - 1)
      f = :erlang.trunc(r)
      lower = Enum.at(values, f)
      upper = Enum.at(values, f + 1)
      lower + (upper - lower) * (r - f)
    end

    [
      List.first(values),
      percentile.(25),
      percentile.(50),
      percentile.(75),
      List.last(values)
    ]
  end
end
