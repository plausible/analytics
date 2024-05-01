defmodule Plausible.Imported.CSVImporterTest do
  use Plausible
  use Plausible.Repo
  use PlausibleWeb.ConnCase
  use Bamboo.Test
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

      assert %{success: 1} =
               Oban.drain_queue(queue: :notify_exported_analytics, with_safety: false)

      # check mailbox
      assert_receive {:delivered_email, email}, _within = :timer.seconds(5)
      assert email.to == [{user.name, user.email}]

      assert email.html_body =~
               ~s[Please click <a href="http://localhost:8000/#{URI.encode_www_form(site.domain)}/download/export">here</a> to start the download process.]

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
      assert Plausible.Stats.Clickhouse.imported_pageview_count(imported_site) == 6325

      # compare original and imported data via stats api requests
      results = fn path, params ->
        get(conn, path, params)
        |> json_response(200)
        |> Map.fetch!("results")
      end

      timeseries = fn params ->
        results.("/api/v1/stats/timeseries", params)
      end

      sorted = fn results, sort_by ->
        Enum.sort_by(results, &Map.fetch!(&1, sort_by))
      end

      breakdown = fn params, sort_by ->
        sorted.(results.("/api/v1/stats/breakdown", params), sort_by)
      end

      common_params = fn site ->
        %{
          "site_id" => site.domain,
          "period" => "custom",
          "date" => "2024-03-28,2024-03-31",
          "with_imported" => true
        }
      end

      breakdown_params = fn site ->
        common_params.(site)
        |> Map.put("metrics", "visitors,visits,pageviews,visit_duration,bounce_rate")
        |> Map.put("limit", 1000)
      end

      # timeseries
      timeseries_params = fn site ->
        Map.put(
          common_params.(site),
          "metrics",
          "visitors,visits,pageviews,views_per_visit,visit_duration,bounce_rate"
        )
      end

      assert timeseries.(timeseries_params.(exported_site)) ==
               timeseries.(timeseries_params.(imported_site))

      # pages
      pages_params = fn site ->
        common_params.(site)
        |> Map.put("metrics", "visitors,visits,pageviews,time_on_page,visit_duration,bounce_rate")
        |> Map.put("limit", 1000)
        |> Map.put("property", "event:page")
      end

      assert breakdown.(pages_params.(exported_site), "page") ==
               breakdown.(pages_params.(imported_site), "page")

      # sources
      sources_params = fn site ->
        params = breakdown_params.(site)
        Map.put(params, "property", "visit:source")
      end

      assert breakdown.(sources_params.(exported_site), "source") ==
               breakdown.(sources_params.(imported_site), "source")

      # utm mediums
      utm_mediums_params = fn site ->
        params = breakdown_params.(site)
        Map.put(params, "property", "visit:utm_medium")
      end

      assert breakdown.(utm_mediums_params.(exported_site), "utm_medium") ==
               breakdown.(utm_mediums_params.(imported_site), "utm_medium")

      # entry pages
      entry_pages_params = fn site ->
        params = breakdown_params.(site)
        Map.put(params, "property", "visit:entry_page")
      end

      assert breakdown.(entry_pages_params.(exported_site), "entry_page") ==
               breakdown.(entry_pages_params.(imported_site), "entry_page")

      # cities
      cities_params = fn site ->
        params = breakdown_params.(site)
        Map.put(params, "property", "visit:city")
      end

      assert breakdown.(cities_params.(exported_site), "city") ==
               breakdown.(cities_params.(imported_site), "city")

      # devices
      devices_params = fn site ->
        params = breakdown_params.(site)
        Map.put(params, "property", "visit:device")
      end

      assert breakdown.(devices_params.(exported_site), "device") ==
               breakdown.(devices_params.(imported_site), "device")

      # browsers
      browsers_params = fn site ->
        params = breakdown_params.(site)
        Map.put(params, "property", "visit:browser")
      end

      assert breakdown.(browsers_params.(exported_site), "browser") ==
               breakdown.(browsers_params.(imported_site), "browser")

      # os
      os_params = fn site ->
        params = breakdown_params.(site)
        Map.put(params, "property", "visit:os")
      end

      assert breakdown.(os_params.(exported_site), "os") ==
               breakdown.(os_params.(imported_site), "os")

      # os versions
      os_version_params = fn site ->
        params = breakdown_params.(site)
        Map.put(params, "property", "visit:os_version")
      end

      assert breakdown.(os_version_params.(exported_site), "os_version") ==
               breakdown.(os_version_params.(imported_site), "os_version")
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
end
