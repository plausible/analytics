defmodule Plausible.Imported.CSVImporterTest do
  use Plausible
  use Plausible.DataCase
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
    setup [:create_user, :create_new_site, :clean_buckets]

    @tag :tmp_dir
    test "it works", %{site: site, user: user, tmp_dir: tmp_dir} do
      # here site_id=2 is plausible.io (staging)

      # docker exec --ti plausible_ch clickhouse client --database plausible_events_db -q 'select * from sessions_v2 sample 100 where site_id=2 and start > \'2024-01-01\' and timestamp < \'2024-02-01\' format CSVWithNames;'
      sessions_csv = """
      "session_id","sign","site_id","user_id","hostname","timestamp","start","is_bounce","entry_page","exit_page","pageviews","events","duration","referrer","referrer_source","country_code","screen_size","operating_system","browser","utm_medium","utm_source","utm_campaign","browser_version","operating_system_version","subdivision1_code","subdivision2_code","city_geoname_id","utm_content","utm_term","transferred_from","entry_meta.key","entry_meta.value","exit_page_hostname"
      3420442013014795741,1,2,4253730134724958,"plausible.io","2024-01-01 04:50:26","2024-01-01 04:50:26",0,"/:dashboard","/:dashboard",2,2,0,"","","US","Mobile","iOS","Safari","","","","17.1","17.1","US-CA","",5392900,"","","","['logged_in']","['true']",""
      5628452905188621818,1,2,5426780003712147,"plausible.io","2024-01-01 17:15:13","2024-01-01 17:12:15",0,"/sites","/sites",12,12,178,"","","US","Desktop","Mac","Chrome","","","","120.0","10.15","US-IL","",4905211,"","","","['logged_in']","['true']",""
      7666160459211319388,1,2,5426780003712147,"plausible.io","2024-01-01 19:01:45","2024-01-01 19:01:45",0,"/sites","/sites",2,2,0,"","","US","Desktop","Mac","Chrome","","","","120.0","10.15","US-IL","",4905211,"","","","['logged_in']","['true']",""
      12269143413821500471,1,2,5426780003712147,"plausible.io","2024-01-01 19:59:22","2024-01-01 19:59:22",0,"/sites","/sites",2,2,0,"","","US","Desktop","Mac","Chrome","","","","120.0","10.15","US-IL","",4905211,"","","","['logged_in']","['true']",""
      13104031403548199029,1,2,7422495910063316,"plausible.io","2024-01-01 12:45:58","2024-01-01 12:25:40",0,"/sites","/:dashboard",6,6,1218,"","","DE","Mobile","iOS","Safari","","","","17.1","17.1","DE-NI","",2918840,"","","","['logged_in']","['true']",""
      12003403275188106302,1,2,1167718876235748,"plausible.io","2024-01-02 06:37:39","2024-01-02 06:34:59",0,"/docs/stats-api","/docs/custom-props/for-custom-events",14,14,160,"google.com","Google","FI","Desktop","Windows","Firefox","","","","121.0","10","FI-18","",632453,"","","","[]","[]",""
      2196962771633480028,1,2,3445731850780337,"plausible.io","2024-01-02 02:26:39","2024-01-02 02:26:39",0,"/:dashboard","/:dashboard",2,2,0,"","","US","Mobile","iOS","Safari","","","","17.1","17.1","US-IL","",4902763,"","","","['logged_in']","['true']",""
      3393877647257005046,1,2,3445731850780337,"plausible.io","2024-01-02 00:47:46","2024-01-02 00:47:46",0,"/:dashboard","/:dashboard",2,2,0,"","","US","Mobile","iOS","Safari","","","","17.1","17.1","US-IL","",4902763,"","","","['logged_in']","['true']",""
      2350060660740786254,1,2,3888797002525748,"plausible.io","2024-01-02 09:55:20","2024-01-02 09:55:20",0,"/sites","/sites",2,2,0,"","","FI","Desktop","Windows","Chrome","","","","120.0","10","FI-11","",634963,"","","","['logged_in']","['true']",""
      10653978521204310672,1,2,3888797002525748,"plausible.io","2024-01-02 07:59:20","2024-01-02 07:56:54",0,"/login","/:dashboard",10,10,146,"","","FI","Desktop","Windows","Chrome","","","","120.0","10","FI-11","",634963,"","","","['logged_in']","['false']",""
      14907626633242401061,1,2,4241359259084596,"plausible.io","2024-01-02 19:26:30","2024-01-02 19:25:25",0,"/:dashboard/settings/visibility","/:dashboard",8,8,65,"agnesroothaan.com","agnesroothaan.com","NL","Desktop","Mac","Firefox","","","","121.0","10.15","","",0,"","","","['logged_in']","['true']",""
      12587481492654003375,1,2,5459917688007592,"plausible.io","2024-01-02 16:24:41","2024-01-02 16:24:41",0,"/","/",2,2,0,"google.com","Google","HU","Mobile","Android","Chrome","","","","120.0","10","HU-PE","",3047647,"","","","[]","[]",""
      18262618460720387360,1,2,8281987717848376,"plausible.io","2024-01-02 20:20:57","2024-01-02 20:20:57",0,"/","/",2,2,0,"","","ES","Desktop","GNU/Linux","Chrome","","","","120.0","","ES-CT","ES-B",3112866,"","","","[]","[]",""
      5827885226956781955,1,2,1620538236508475,"plausible.io","2024-01-03 16:14:20","2024-01-03 16:14:18",0,"/sites","/:dashboard",3,3,2,"","","US","Desktop","Mac","Safari","","","","17.2","10.15","US-MD","",4351977,"","","","['logged_in']","['true']",""
      12533098435721363684,1,2,1620538236508475,"plausible.io","2024-01-03 15:25:05","2024-01-03 15:25:02",0,"/sites","/:dashboard",3,3,3,"","","US","Desktop","Mac","Safari","","","","17.2","10.15","US-MD","",4351977,"","","","['logged_in']","['true']",""
      14403993981374023970,1,2,1620538236508475,"plausible.io","2024-01-03 18:08:14","2024-01-03 18:08:12",0,"/sites","/:dashboard",4,4,2,"","","US","Desktop","Mac","Safari","","","","17.2","10.15","US-MD","",4351977,"","","","['logged_in']","['true']",""
      7827721650756309023,1,2,1991080545489942,"plausible.io","2024-01-03 14:22:04","2024-01-03 14:21:58",0,"/:dashboard","/:dashboard",6,6,6,"","","DE","Mobile","iOS","Safari","","","","16.6","16.7","DE-HE","",2925533,"","","","['logged_in']","['true']",""
      10923252767260442011,1,2,2442170009453171,"plausible.io","2024-01-03 11:25:52","2024-01-03 11:24:28",0,"/","/plausible.io",4,4,84,"google.com","Google","FR","Desktop","Mac","Chrome","","","","119.0","10.15","FR-IDF","FR-92",3012649,"","","","[]","[]",""
      12530768248758226381,1,2,3567343926552584,"plausible.io","2024-01-03 19:28:22","2024-01-03 19:28:22",0,"/:dashboard","/:dashboard",2,2,0,"","","US","Desktop","Mac","Chrome","","","","120.0","10.15","US-DC","",4140963,"","","","['logged_in']","['true']",""
      11680188501286356359,1,2,7876703414044630,"plausible.io","2024-01-03 02:38:06","2024-01-03 02:38:06",1,"/","/",1,1,0,"","","SG","Desktop","Windows","Firefox","","","","121.0","10","","",1880252,"","","","[]","[]",""
      13701666527546080143,1,2,7876703414044630,"plausible.io","2024-01-03 02:38:06","2024-01-03 02:38:06",1,"/","/",1,1,0,"","","SG","Desktop","Windows","Firefox","","","","121.0","10","","",1880252,"","","","[]","[]",""
      2141028661119851837,1,2,1386831400952234,"plausible.io","2024-01-04 08:44:31","2024-01-04 08:41:20",0,"/sites","/:dashboard",7,7,191,"","","PL","Desktop","Mac","Chrome","","","","120.0","10.15","PL-12","",3094802,"","","","['logged_in']","['true']",""
      7169584723214728062,1,2,1386831400952234,"plausible.io","2024-01-04 07:55:59","2024-01-04 07:53:33",0,"/sites","/:dashboard",8,8,146,"","","PL","Desktop","Mac","Chrome","","","","120.0","10.15","PL-12","",3094802,"","","","['logged_in']","['true']",""
      1470061201078944177,1,2,2902752707980008,"plausible.io","2024-01-04 14:23:28","2024-01-04 14:18:58",0,"/login","/:dashboard/settings/general",24,24,270,"","","NL","Desktop","Windows","Chrome","","","","120.0","10","NL-UT","",2753908,"","","","['logged_in']","['false']",""
      14319406160426541547,1,2,3608876477749321,"plausible.io","2024-01-04 19:09:44","2024-01-04 19:09:43",0,"/docs/self-hosting-configuration","/docs/self-hosting-configuration",2,2,1,"google.com","Google","US","Desktop","GNU/Linux","Chrome","","","","120.0","","US-MN","",5037649,"","","","[]","[]",""
      11460673895771375827,1,2,6809697864904680,"plausible.io","2024-01-04 13:57:38","2024-01-04 13:57:38",1,"/","/",1,1,0,"","","CZ","Desktop","Windows","Chrome","","","","120.0","10","CZ-80","CZ-806",3068799,"","","","[]","[]",""
      9978989278393247774,1,2,2669285517751856,"plausible.io","2024-01-05 02:31:21","2024-01-05 02:31:19",0,"/sites","/login",6,6,2,"","","US","Mobile","iOS","Safari","","","","17.1","17.1","US-FL","",4164143,"","","","['logged_in']","['true']",""
      9201278843536007283,1,2,3463383581825712,"plausible.io","2024-01-05 15:21:15","2024-01-05 15:21:15",0,"/sites","/sites",2,2,0,"","","GB","Desktop","Mac","Chrome","","","","120.0","10.15","GB-ENG","GB-LEC",2643567,"","","","['logged_in']","['true']",""
      13676620482053998436,1,2,3463383581825712,"plausible.io","2024-01-05 20:15:33","2024-01-05 20:15:33",0,"/sites","/sites",2,2,0,"","","GB","Desktop","Mac","Chrome","","","","120.0","10.15","GB-ENG","GB-LEC",2643567,"","","","['logged_in']","['true']",""
      15921980883715613085,1,2,4757581401924555,"plausible.io","2024-01-05 13:17:05","2024-01-05 13:17:05",0,"/","/",2,2,0,"google.com","Google","SK","Desktop","Windows","Chrome","","","","120.0","10","SK-BL","",3060972,"","","","[]","[]",""
      808838754918763907,1,2,7052025517906368,"plausible.io","2024-01-05 20:12:44","2024-01-05 20:12:41",0,"/:dashboard","/:dashboard",4,4,3,"","","DE","Mobile","iOS","Safari","","","","16.6","16.7","DE-TH","",2831276,"","","","['logged_in']","['true']",""
      17003323142756615129,1,2,8063314897767234,"plausible.io","2024-01-05 21:06:38","2024-01-05 21:06:37",0,"/:dashboard","/:dashboard",2,2,1,"","","US","Desktop","Mac","Chrome","","","","120.0","10.15","US-FL","",4164138,"","","","['logged_in']","['true']",""
      17555898823972588247,1,2,2674567519747343,"plausible.io","2024-01-06 13:31:16","2024-01-06 13:31:16",0,"/sites","/sites",2,2,0,"","","PK","Desktop","Mac","Chrome","","","","119.0","10.15","PK-PB","",1172451,"","","","['logged_in']","['true']",""
      2152344308278295085,1,2,4905999763529676,"plausible.io","2024-01-06 05:16:28","2024-01-06 05:16:04",0,"/","/",6,6,24,"youtube.com","Youtube","AU","Desktop","Windows","Chrome","","","","120.0","10","AU-VIC","",2158177,"","","","[]","[]",""
      11822674518987888234,1,2,8569605319906646,"plausible.io","2024-01-06 11:32:20","2024-01-06 11:32:20",0,"/:dashboard","/:dashboard",2,2,0,"","","FR","Desktop","Mac","Chrome","","","","120.0","10.15","","",0,"","","","['logged_in']","['true']",""
      11890601100179268661,1,2,8569605319906646,"plausible.io","2024-01-06 07:58:06","2024-01-06 07:58:06",0,"/:dashboard","/:dashboard",2,2,0,"","","FR","Desktop","Mac","Chrome","","","","120.0","10.15","","",0,"","","","['logged_in']","['true']",""
      11985629085256425332,1,2,8569605319906646,"plausible.io","2024-01-06 09:07:40","2024-01-06 08:49:24",0,"/:dashboard","/:dashboard",4,4,1096,"","","FR","Desktop","Mac","Chrome","","","","120.0","10.15","","",0,"","","","['logged_in']","['true']",""
      14087710344798001358,1,2,8569605319906646,"plausible.io","2024-01-06 10:53:49","2024-01-06 10:53:49",0,"/:dashboard","/:dashboard",2,2,0,"","","FR","Desktop","Mac","Chrome","","","","120.0","10.15","","",0,"","","","['logged_in']","['true']",""
      17876788823258832237,1,2,8569605319906646,"plausible.io","2024-01-06 12:44:07","2024-01-06 12:44:07",0,"/:dashboard","/:dashboard",2,2,0,"","","FR","Desktop","Mac","Chrome","","","","120.0","10.15","","",0,"","","","['logged_in']","['true']",""
      2046772439473350003,1,2,1013778694548289,"plausible.io","2024-01-07 23:29:09","2024-01-07 23:29:09",0,"/:dashboard","/:dashboard",2,2,0,"github.com","GitHub","US","Desktop","Windows","Microsoft Edge","","","","120.0","10","US-WA","",5800112,"","","","['logged_in']","['false']",""
      11034410302316631842,1,2,3964598939404401,"plausible.io","2024-01-07 14:46:34","2024-01-07 14:38:17",0,"/:dashboard","/:dashboard",4,4,497,"","","GB","Mobile","iOS","Safari","","","","17.1","17.1","GB-ENG","GB-RUT",2641128,"","","","['logged_in']","['true']",""
      4023629694253364848,1,2,319436247539751,"plausible.io","2024-01-08 10:48:09","2024-01-08 10:48:09",0,"/sites","/sites",2,2,0,"","","DK","Desktop","Windows","Chrome","","","","120.0","10","DK-84","",2621942,"","","","['logged_in']","['true']",""
      10608108878218856706,1,2,319436247539751,"plausible.io","2024-01-08 08:39:21","2024-01-08 08:39:21",1,"/sites","/sites",1,1,0,"","","DK","Desktop","Windows","Chrome","","","","120.0","10","DK-84","",2621942,"","","","['logged_in']","['true']",""
      15765385095703529711,1,2,319436247539751,"plausible.io","2024-01-08 08:39:21","2024-01-08 08:39:21",1,"/sites","/sites",1,1,0,"","","DK","Desktop","Windows","Chrome","","","","120.0","10","DK-84","",2621942,"","","","['logged_in']","['true']",""
      10383471554513738829,1,2,1262842032889677,"plausible.io","2024-01-08 03:22:06","2024-01-08 03:22:00",0,"/sites","/:dashboard",4,4,6,"","","US","Mobile","Android","Chrome","","","","121.0","10","US-WA","",5809844,"","","","['logged_in']","['true']",""
      317176108081521816,1,2,1491841464516787,"plausible.io","2024-01-08 16:04:32","2024-01-08 15:51:27",0,"/:dashboard","/:dashboard",4,4,785,"","","AT","Mobile","iOS","Chrome","","","","120.0","16.1","AT-9","",2761369,"","","","['logged_in']","['true']",""
      1163026024766963146,1,2,1491841464516787,"plausible.io","2024-01-08 20:55:28","2024-01-08 20:29:18",0,"/:dashboard","/:dashboard",6,6,1570,"","","AT","Mobile","iOS","Chrome","","","","120.0","16.1","AT-9","",2761369,"","","","['logged_in']","['true']",""
      5721483021860695203,1,2,1491841464516787,"plausible.io","2024-01-08 18:31:26","2024-01-08 17:49:05",0,"/:dashboard","/:dashboard",20,20,2541,"","","AT","Mobile","iOS","Chrome","","","","120.0","16.1","AT-9","",2761369,"","","","['logged_in']","['true']",""
      11216009315276519478,1,2,1491841464516787,"plausible.io","2024-01-08 22:20:16","2024-01-08 21:48:44",0,"/:dashboard","/:dashboard",16,16,1892,"","","AT","Mobile","iOS","Chrome","","","","120.0","16.1","AT-9","",2761369,"","","","['logged_in']","['true']",""
      16485025429768064611,1,2,1491841464516787,"plausible.io","2024-01-08 17:05:13","2024-01-08 17:04:19",0,"/:dashboard","/:dashboard",3,3,54,"","","AT","Mobile","iOS","Chrome","","","","120.0","16.1","AT-9","",2761369,"","","","['logged_in']","['true']",""
      16514624428580207244,1,2,1491841464516787,"plausible.io","2024-01-08 15:08:15","2024-01-08 15:01:54",0,"/:dashboard","/:dashboard",12,12,381,"","","AT","Mobile","iOS","Chrome","","","","120.0","16.1","AT-9","",2761369,"","","","['logged_in']","['true']",""
      11477473954404184805,1,2,2846916618357090,"plausible.io","2024-01-08 14:06:03","2024-01-08 14:05:12",0,"/sites","/:dashboard",6,6,51,"","","HR","Mobile","iOS","Safari","","","","16.1","16.1","HR-05","",3188383,"","","","['logged_in']","['true']",""
      11622063005157845266,1,2,2846916618357090,"plausible.io","2024-01-08 18:33:44","2024-01-08 18:33:40",0,"/sites","/:dashboard",4,4,4,"","","HR","Mobile","iOS","Safari","","","","16.1","16.1","HR-05","",3188383,"","","","['logged_in']","['true']",""
      13674329651601068563,1,2,2846916618357090,"plausible.io","2024-01-08 16:16:41","2024-01-08 16:16:41",0,"/:dashboard","/:dashboard",2,2,0,"","","HR","Mobile","iOS","Safari","","","","16.1","16.1","HR-05","",3188383,"","","","['logged_in']","['true']",""
      3166433125635228690,1,2,5222702184143432,"plausible.io","2024-01-08 09:32:10","2024-01-08 09:30:12",0,"/sites","/sites",6,6,118,"","","JP","Desktop","Mac","Safari","","","","17.2","10.15","JP-13","",1850147,"","","","['logged_in']","['true']",""
      4569763345927955250,1,2,5222702184143432,"plausible.io","2024-01-08 22:40:50","2024-01-08 22:40:48",0,"/sites","/:dashboard",4,4,2,"","","JP","Desktop","Mac","Safari","","","","17.2","10.15","JP-13","",1850147,"","","","['logged_in']","['true']",""
      6181469944402161036,1,2,5222702184143432,"plausible.io","2024-01-08 23:57:15","2024-01-08 23:57:15",0,"/sites","/sites",2,2,0,"","","JP","Desktop","Mac","Safari","","","","17.2","10.15","JP-13","",1850147,"","","","['logged_in']","['true']",""
      15600927922278337000,1,2,4882350962611626,"plausible.io","2024-01-09 03:01:18","2024-01-09 03:01:16",0,"/:dashboard","/:dashboard",4,4,2,"","","US","Mobile","iOS","Safari","","","","17.2","17.2","US-NY","",5128581,"","","","['logged_in']","['true']",""
      3023318554607489584,1,2,5827154319017369,"plausible.io","2024-01-09 18:18:05","2024-01-09 18:17:55",0,"/:dashboard","/:dashboard",4,4,10,"","","DK","Desktop","Mac","Safari","","","","16.5","10.15","DK-82","",2624652,"","","","['logged_in']","['true']",""
      13797120320504765078,1,2,5836634664072177,"plausible.io","2024-01-09 07:23:18","2024-01-09 07:23:18",0,"/:dashboard","/:dashboard",2,2,0,"","","GB","Mobile","iOS","Safari","","","","16.6","16.6","GB-ENG","GB-WOR",2633563,"","","","['logged_in']","['true']",""
      17521253752783320192,1,2,5836634664072177,"plausible.io","2024-01-09 06:46:18","2024-01-09 06:46:18",0,"/:dashboard","/:dashboard",2,2,0,"","","GB","Mobile","iOS","Safari","","","","16.6","16.6","GB-ENG","GB-WOR",2633563,"","","","['logged_in']","['true']",""
      18199445865514564329,1,2,6058145466525697,"plausible.io","2024-01-09 13:41:14","2024-01-09 13:41:14",0,"/:dashboard","/:dashboard",2,2,0,"","","AT","Mobile","iOS","Safari","","","","16.3","16.3","AT-9","",2761369,"","","","['logged_in']","['true']",""
      16881781935249629725,1,2,8251349988663916,"plausible.io","2024-01-09 08:56:51","2024-01-09 08:56:51",0,"/:dashboard","/:dashboard",2,2,0,"","","DK","Desktop","Mac","Chrome","","","","120.0","10.15","DK-82","",2621710,"","","","['logged_in']","['true']",""
      8879126321530428851,1,2,8627663563487652,"plausible.io","2024-01-09 08:09:00","2024-01-09 08:09:00",1,"/:dashboard","/:dashboard",1,1,0,"","","SE","Desktop","Mac","Safari","","","","17.1","10.15","SE-AB","",2673730,"","","","['logged_in']","['true']",""
      14522258747882651516,1,2,8627663563487652,"plausible.io","2024-01-09 06:56:09","2024-01-09 06:56:09",0,"/:dashboard","/:dashboard",2,2,0,"","","SE","Desktop","Mac","Safari","","","","17.1","10.15","SE-AB","",2673730,"","","","['logged_in']","['true']",""
      15441983676622845991,1,2,8627663563487652,"plausible.io","2024-01-09 09:02:15","2024-01-09 09:02:15",0,"/:dashboard","/:dashboard",2,2,0,"","","SE","Desktop","Mac","Safari","","","","17.1","10.15","SE-AB","",2673730,"","","","['logged_in']","['true']",""
      17479673357660235083,1,2,8627663563487652,"plausible.io","2024-01-09 08:09:00","2024-01-09 08:09:00",1,"/:dashboard","/:dashboard",1,1,0,"","","SE","Desktop","Mac","Safari","","","","17.1","10.15","SE-AB","",2673730,"","","","['logged_in']","['true']",""
      13105315951801459554,1,2,7654343868648363,"plausible.io","2024-01-10 04:36:42","2024-01-10 04:36:42",0,"/:dashboard","/:dashboard",2,2,0,"","","US","Desktop","Mac","Chrome","","","","120.0","10.15","US-AZ","",5308655,"","","","['logged_in']","['true']",""
      1205382852325419789,1,2,8428766957603826,"plausible.io","2024-01-10 15:51:35","2024-01-10 15:51:35",0,"/share/:dashboard","/share/:dashboard",2,2,0,"","","GB","Desktop","Mac","Chrome","","","","120.0","10.15","GB-SCT","GB-EDH",2650225,"","","","['logged_in']","['false']",""
      15269584988784493510,1,2,8428766957603826,"plausible.io","2024-01-10 15:14:36","2024-01-10 15:14:36",0,"/share/:dashboard","/share/:dashboard",2,2,0,"","","GB","Desktop","Mac","Chrome","","","","120.0","10.15","GB-SCT","GB-EDH",2650225,"","","","['logged_in']","['false']",""
      4812257357741602584,1,2,8482183136122890,"plausible.io","2024-01-10 05:42:11","2024-01-10 05:42:11",0,"/sites","/sites",2,2,0,"","","BE","Mobile","iOS","Safari","","","","17.2","17.2","BE-BRU","",2800866,"","","","['logged_in']","['true']",""
      1478764090069704746,1,2,6095662044207412,"plausible.io","2024-01-11 22:03:41","2024-01-11 22:03:41",0,"/","/",2,2,0,"google.com","Google","GB","Desktop","GNU/Linux","Chrome","","","","115.0","","GB-ENG","GB-ESS",2643160,"","","","[]","[]",""
      3650092153238040894,1,2,6305215667067726,"plausible.io","2024-01-11 08:29:15","2024-01-11 08:29:15",1,"/:dashboard","/:dashboard",1,1,0,"","","FR","Desktop","Windows","Chrome","","","","120.0","10","FR-BRE","FR-29",3017624,"","","","['logged_in']","['true']",""
      4212029886480057967,1,2,7715581262488642,"plausible.io","2024-01-11 20:34:50","2024-01-11 20:34:17",0,"/","/vs-cloudflare-web-analytics",4,4,33,"google.com","Google","FI","Desktop","Windows","Chrome","","","","120.0","10","FI-19","",637948,"","","","[]","[]",""
      9408683463088063451,1,2,3220646452433704,"plausible.io","2024-01-12 17:47:10","2024-01-12 17:47:08",0,"/sites","/:dashboard",2,2,2,"","","PT","Desktop","Windows","Chrome","","","","120.0","10","PT-13","",2733249,"","","","['logged_in']","['true']",""
      10718621414717637663,1,2,3220646452433704,"plausible.io","2024-01-12 11:57:02","2024-01-12 11:57:00",0,"/sites","/:dashboard",4,4,2,"","","PT","Desktop","Windows","Chrome","","","","120.0","10","PT-13","",2733249,"","","","['logged_in']","['true']",""
      14972234457589972545,1,2,3220646452433704,"plausible.io","2024-01-12 13:01:09","2024-01-12 13:01:07",0,"/sites","/:dashboard",3,3,2,"","","PT","Desktop","Windows","Chrome","","","","120.0","10","PT-13","",2733249,"","","","['logged_in']","['true']",""
      16233290597231281024,1,2,3220646452433704,"plausible.io","2024-01-12 17:10:57","2024-01-12 16:17:12",0,"/sites","/:dashboard",15,15,3225,"","","PT","Desktop","Windows","Chrome","","","","120.0","10","PT-13","",2733249,"","","","['logged_in']","['true']",""
      17588140732813363895,1,2,3220646452433704,"plausible.io","2024-01-12 17:47:08","2024-01-12 17:47:08",1,"/sites","/sites",1,1,0,"","","PT","Desktop","Windows","Chrome","","","","120.0","10","PT-13","",2733249,"","","","['logged_in']","['true']",""
      17662261298038438805,1,2,3220646452433704,"plausible.io","2024-01-12 11:10:36","2024-01-12 11:10:33",0,"/sites","/:dashboard",4,4,3,"","","PT","Desktop","Windows","Chrome","","","","120.0","10","PT-13","",2733249,"","","","['logged_in']","['true']",""
      17945264885979215739,1,2,4993417743097898,"plausible.io","2024-01-12 20:04:18","2024-01-12 19:59:02",0,"/sites","/vs-cloudflare-web-analytics",20,20,316,"","","MK","Desktop","Mac","Safari","","","","17.2","10.15","","",785842,"","","","['logged_in']","['true']",""
      18109938131442810270,1,2,4993417743097898,"plausible.io","2024-01-12 11:07:52","2024-01-12 11:07:44",0,"/sites","/:dashboard",4,4,8,"","","MK","Desktop","Mac","Safari","","","","17.2","10.15","","",785842,"","","","['logged_in']","['true']",""
      16006747592031739775,1,2,5292369883223652,"plausible.io","2024-01-12 09:47:02","2024-01-12 09:47:02",0,"/:dashboard","/:dashboard",2,2,0,"","","HR","Mobile","iOS","Safari","","","","16.1","16.1","HR-21","",0,"","","","['logged_in']","['true']",""
      2750043803984928038,1,2,6441703167470208,"plausible.io","2024-01-12 13:46:13","2024-01-12 13:45:47",0,"/:dashboard","/:dashboard",10,10,26,"","","AT","Desktop","Mac","Chrome","","","","111.0","10.15","AT-8","",2779674,"","","","['logged_in']","['true']",""
      5060322712081619171,1,2,2678847443631738,"plausible.io","2024-01-13 22:10:51","2024-01-13 22:10:51",1,"/:dashboard","/:dashboard",1,1,0,"","","FR","Desktop","Mac","Safari","","","","17.2","10.15","FR-OCC","FR-34",2970144,"","","","['logged_in']","['true']",""
      5543282897613343645,1,2,2678847443631738,"plausible.io","2024-01-13 20:33:36","2024-01-13 20:33:36",0,"/:dashboard","/:dashboard",2,2,0,"","","FR","Desktop","Mac","Safari","","","","17.2","10.15","FR-OCC","FR-34",2970144,"","","","['logged_in']","['true']",""
      6249657084237035719,1,2,2678847443631738,"plausible.io","2024-01-13 22:10:51","2024-01-13 22:10:51",1,"/:dashboard","/:dashboard",1,1,0,"","","FR","Desktop","Mac","Safari","","","","17.2","10.15","FR-OCC","FR-34",2970144,"","","","['logged_in']","['true']",""
      9855390470565126145,1,2,2678847443631738,"plausible.io","2024-01-13 11:04:14","2024-01-13 11:04:14",0,"/:dashboard","/:dashboard",2,2,0,"","","FR","Desktop","Mac","Safari","","","","17.2","10.15","FR-OCC","FR-34",2970144,"","","","['logged_in']","['true']",""
      12456905080224463199,1,2,2678847443631738,"plausible.io","2024-01-13 09:39:59","2024-01-13 09:39:59",0,"/:dashboard","/:dashboard",2,2,0,"","","FR","Desktop","Mac","Safari","","","","17.2","10.15","FR-OCC","FR-34",2970144,"","","","['logged_in']","['true']",""
      17555225793888623733,1,2,2678847443631738,"plausible.io","2024-01-13 19:12:16","2024-01-13 19:12:14",0,"/:dashboard","/:dashboard",4,4,2,"","","FR","Desktop","Mac","Safari","","","","17.2","10.15","FR-OCC","FR-34",2970144,"","","","['logged_in']","['true']",""
      13726673238447225883,1,2,7535134733447910,"plausible.io","2024-01-14 17:47:37","2024-01-14 17:47:25",0,"/sites","/sites/new",8,8,12,"","","FI","Desktop","Ubuntu","Firefox","","","","121.0","","FI-18","",658225,"","","","['logged_in']","['true']",""
      5235106120742737722,1,2,74318416938695,"plausible.io","2024-01-15 08:45:14","2024-01-15 08:44:42",0,"/sites","/settings",6,6,32,"","","FR","Desktop","Mac","Chrome","","","","120.0","10.15","FR-IDF","FR-75",2988507,"","","","['logged_in']","['true']",""
      10385995742944960297,1,2,5720971657589925,"plausible.io","2024-01-15 20:31:17","2024-01-15 20:31:17",0,"/login","/login",2,2,0,"","","  ","Tablet","iOS","Chrome","","","","120.0","17.2","","",0,"","","","['logged_in']","['false']",""
      16133283732806147076,1,2,7985949775551653,"plausible.io","2024-01-15 14:11:22","2024-01-15 14:11:22",1,"/sites","/sites",1,1,0,"","","MX","Desktop","GNU/Linux","Chrome","","","","120.0","","MX-YUC","",3523349,"","","","['logged_in']","['true']",""
      8268552482280430197,1,2,7284010782363557,"plausible.io","2024-01-23 03:58:00","2024-01-23 03:58:00",0,"/","/",2,2,0,"","","US","Desktop","Mac","Chrome","","","","120.0","10.15","US-CA","",5392171,"","","","[]","[]",""
      """

      # docker exec -ti plausible_ch clickhouse client --database plausible_events_db -q 'select * from events_v2 where user_id in (select distinct user_id from sessions_v2 sample 100 where site_id=2 and start > \'2024-01-01\' and timestamp < \'2024-02-01\') and site_id=2 and timestamp > \'2024-01-01\' and timestamp < \'2024-02-01\' format CSVWithNames'
      events_csv = """
      "timestamp","name","site_id","user_id","session_id","hostname","pathname","referrer","referrer_source","country_code","screen_size","operating_system","browser","utm_medium","utm_source","utm_campaign","meta.key","meta.value","browser_version","operating_system_version","subdivision1_code","subdivision2_code","city_geoname_id","utm_content","utm_term","revenue_reporting_amount","revenue_reporting_currency","revenue_source_amount","revenue_source_currency"
      "2024-01-01 04:50:26","pageview",2,4253730134724958,3420442013014795741,"plausible.io","/:dashboard","","","US","Mobile","iOS","Safari","","","","['logged_in']","['true']","17.1","17.1","US-CA","",5392900,"","",\\N,"   ",\\N,"   "
      "2024-01-01 04:50:26","pageview",2,4253730134724958,3420442013014795741,"plausible.io","/:dashboard","","","US","Mobile","iOS","Safari","","","","['logged_in']","['true']","17.1","17.1","US-CA","",5392900,"","",\\N,"   ",\\N,"   "
      "2024-01-01 17:12:15","pageview",2,5426780003712147,5628452905188621818,"plausible.io","/sites","","","US","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","US-IL","",4905211,"","",\\N,"   ",\\N,"   "
      "2024-01-01 17:12:15","pageview",2,5426780003712147,5628452905188621818,"plausible.io","/sites","","","US","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","US-IL","",4905211,"","",\\N,"   ",\\N,"   "
      "2024-01-01 17:12:17","pageview",2,5426780003712147,5628452905188621818,"plausible.io","/:dashboard","","","US","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","US-IL","",4905211,"","",\\N,"   ",\\N,"   "
      "2024-01-01 17:12:17","pageview",2,5426780003712147,5628452905188621818,"plausible.io","/:dashboard","","","US","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","US-IL","",4905211,"","",\\N,"   ",\\N,"   "
      "2024-01-01 17:12:20","pageview",2,5426780003712147,5628452905188621818,"plausible.io","/sites","","","US","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","US-IL","",4905211,"","",\\N,"   ",\\N,"   "
      "2024-01-01 17:12:20","pageview",2,5426780003712147,5628452905188621818,"plausible.io","/sites","","","US","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","US-IL","",4905211,"","",\\N,"   ",\\N,"   "
      "2024-01-01 17:12:21","pageview",2,5426780003712147,5628452905188621818,"plausible.io","/:dashboard","","","US","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","US-IL","",4905211,"","",\\N,"   ",\\N,"   "
      "2024-01-01 17:12:21","pageview",2,5426780003712147,5628452905188621818,"plausible.io","/:dashboard","","","US","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","US-IL","",4905211,"","",\\N,"   ",\\N,"   "
      "2024-01-01 17:12:22","pageview",2,5426780003712147,5628452905188621818,"plausible.io","/sites","","","US","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","US-IL","",4905211,"","",\\N,"   ",\\N,"   "
      "2024-01-01 17:12:22","pageview",2,5426780003712147,5628452905188621818,"plausible.io","/sites","","","US","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","US-IL","",4905211,"","",\\N,"   ",\\N,"   "
      "2024-01-01 17:15:13","pageview",2,5426780003712147,5628452905188621818,"plausible.io","/sites","","","US","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","US-IL","",4905211,"","",\\N,"   ",\\N,"   "
      "2024-01-01 17:15:13","pageview",2,5426780003712147,5628452905188621818,"plausible.io","/sites","","","US","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","US-IL","",4905211,"","",\\N,"   ",\\N,"   "
      "2024-01-01 19:01:45","pageview",2,5426780003712147,7666160459211319388,"plausible.io","/sites","","","US","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","US-IL","",4905211,"","",\\N,"   ",\\N,"   "
      "2024-01-01 19:01:45","pageview",2,5426780003712147,7666160459211319388,"plausible.io","/sites","","","US","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","US-IL","",4905211,"","",\\N,"   ",\\N,"   "
      "2024-01-01 19:59:22","pageview",2,5426780003712147,12269143413821500471,"plausible.io","/sites","","","US","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","US-IL","",4905211,"","",\\N,"   ",\\N,"   "
      "2024-01-01 19:59:22","pageview",2,5426780003712147,12269143413821500471,"plausible.io","/sites","","","US","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","US-IL","",4905211,"","",\\N,"   ",\\N,"   "
      "2024-01-01 12:25:40","pageview",2,7422495910063316,13104031403548199029,"plausible.io","/sites","","","DE","Mobile","iOS","Safari","","","","['logged_in']","['true']","17.1","17.1","DE-NI","",2918840,"","",\\N,"   ",\\N,"   "
      "2024-01-01 12:25:40","pageview",2,7422495910063316,13104031403548199029,"plausible.io","/sites","","","DE","Mobile","iOS","Safari","","","","['logged_in']","['true']","17.1","17.1","DE-NI","",2918840,"","",\\N,"   ",\\N,"   "
      "2024-01-01 12:25:43","pageview",2,7422495910063316,13104031403548199029,"plausible.io","/:dashboard","","","DE","Mobile","iOS","Safari","","","","['logged_in']","['true']","17.1","17.1","DE-NI","",2918840,"","",\\N,"   ",\\N,"   "
      "2024-01-01 12:25:43","pageview",2,7422495910063316,13104031403548199029,"plausible.io","/:dashboard","","","DE","Mobile","iOS","Safari","","","","['logged_in']","['true']","17.1","17.1","DE-NI","",2918840,"","",\\N,"   ",\\N,"   "
      "2024-01-01 12:45:58","pageview",2,7422495910063316,13104031403548199029,"plausible.io","/:dashboard","","","DE","Mobile","iOS","Safari","","","","['logged_in']","['true']","17.1","17.1","DE-NI","",2918840,"","",\\N,"   ",\\N,"   "
      "2024-01-01 12:45:58","pageview",2,7422495910063316,13104031403548199029,"plausible.io","/:dashboard","","","DE","Mobile","iOS","Safari","","","","['logged_in']","['true']","17.1","17.1","DE-NI","",2918840,"","",\\N,"   ",\\N,"   "
      "2024-01-02 06:34:59","pageview",2,1167718876235748,12003403275188106302,"plausible.io","/docs/stats-api","google.com","Google","FI","Desktop","Windows","Firefox","","","","[]","[]","121.0","10","FI-18","",632453,"","",\\N,"   ",\\N,"   "
      "2024-01-02 06:34:59","pageview",2,1167718876235748,12003403275188106302,"plausible.io","/docs/stats-api","google.com","Google","FI","Desktop","Windows","Firefox","","","","[]","[]","121.0","10","FI-18","",632453,"","",\\N,"   ",\\N,"   "
      "2024-01-02 06:35:55","pageview",2,1167718876235748,12003403275188106302,"plausible.io","/docs/events-api","google.com","Google","FI","Desktop","Windows","Firefox","","","","[]","[]","121.0","10","FI-18","",632453,"","",\\N,"   ",\\N,"   "
      "2024-01-02 06:35:55","pageview",2,1167718876235748,12003403275188106302,"plausible.io","/docs/events-api","google.com","Google","FI","Desktop","Windows","Firefox","","","","[]","[]","121.0","10","FI-18","",632453,"","",\\N,"   ",\\N,"   "
      "2024-01-02 06:36:46","pageview",2,1167718876235748,12003403275188106302,"plausible.io","/docs/proxy/introduction","google.com","Google","FI","Desktop","Windows","Firefox","","","","[]","[]","121.0","10","FI-18","",632453,"","",\\N,"   ",\\N,"   "
      "2024-01-02 06:36:46","pageview",2,1167718876235748,12003403275188106302,"plausible.io","/docs/proxy/introduction","google.com","Google","FI","Desktop","Windows","Firefox","","","","[]","[]","121.0","10","FI-18","",632453,"","",\\N,"   ",\\N,"   "
      "2024-01-02 06:37:01","pageview",2,1167718876235748,12003403275188106302,"plausible.io","/docs/events-api","google.com","Google","FI","Desktop","Windows","Firefox","","","","[]","[]","121.0","10","FI-18","",632453,"","",\\N,"   ",\\N,"   "
      "2024-01-02 06:37:01","pageview",2,1167718876235748,12003403275188106302,"plausible.io","/docs/events-api","google.com","Google","FI","Desktop","Windows","Firefox","","","","[]","[]","121.0","10","FI-18","",632453,"","",\\N,"   ",\\N,"   "
      "2024-01-02 06:37:14","pageview",2,1167718876235748,12003403275188106302,"plausible.io","/docs/custom-props/for-custom-events","google.com","Google","FI","Desktop","Windows","Firefox","","","","[]","[]","121.0","10","FI-18","",632453,"","",\\N,"   ",\\N,"   "
      "2024-01-02 06:37:14","pageview",2,1167718876235748,12003403275188106302,"plausible.io","/docs/custom-props/for-custom-events","google.com","Google","FI","Desktop","Windows","Firefox","","","","[]","[]","121.0","10","FI-18","",632453,"","",\\N,"   ",\\N,"   "
      "2024-01-02 06:37:33","pageview",2,1167718876235748,12003403275188106302,"plausible.io","/docs/custom-props/props-dashboard","google.com","Google","FI","Desktop","Windows","Firefox","","","","[]","[]","121.0","10","FI-18","",632453,"","",\\N,"   ",\\N,"   "
      "2024-01-02 06:37:33","pageview",2,1167718876235748,12003403275188106302,"plausible.io","/docs/custom-props/props-dashboard","google.com","Google","FI","Desktop","Windows","Firefox","","","","[]","[]","121.0","10","FI-18","",632453,"","",\\N,"   ",\\N,"   "
      "2024-01-02 06:37:39","pageview",2,1167718876235748,12003403275188106302,"plausible.io","/docs/custom-props/for-custom-events","google.com","Google","FI","Desktop","Windows","Firefox","","","","[]","[]","121.0","10","FI-18","",632453,"","",\\N,"   ",\\N,"   "
      "2024-01-02 06:37:39","pageview",2,1167718876235748,12003403275188106302,"plausible.io","/docs/custom-props/for-custom-events","google.com","Google","FI","Desktop","Windows","Firefox","","","","[]","[]","121.0","10","FI-18","",632453,"","",\\N,"   ",\\N,"   "
      "2024-01-02 00:47:46","pageview",2,3445731850780337,3393877647257005046,"plausible.io","/:dashboard","","","US","Mobile","iOS","Safari","","","","['logged_in']","['true']","17.1","17.1","US-IL","",4902763,"","",\\N,"   ",\\N,"   "
      "2024-01-02 00:47:46","pageview",2,3445731850780337,3393877647257005046,"plausible.io","/:dashboard","","","US","Mobile","iOS","Safari","","","","['logged_in']","['true']","17.1","17.1","US-IL","",4902763,"","",\\N,"   ",\\N,"   "
      "2024-01-02 02:26:39","pageview",2,3445731850780337,2196962771633480028,"plausible.io","/:dashboard","","","US","Mobile","iOS","Safari","","","","['logged_in']","['true']","17.1","17.1","US-IL","",4902763,"","",\\N,"   ",\\N,"   "
      "2024-01-02 02:26:39","pageview",2,3445731850780337,2196962771633480028,"plausible.io","/:dashboard","","","US","Mobile","iOS","Safari","","","","['logged_in']","['true']","17.1","17.1","US-IL","",4902763,"","",\\N,"   ",\\N,"   "
      "2024-01-02 07:56:54","pageview",2,3888797002525748,10653978521204310672,"plausible.io","/login","","","FI","Desktop","Windows","Chrome","","","","['logged_in']","['false']","120.0","10","FI-11","",634963,"","",\\N,"   ",\\N,"   "
      "2024-01-02 07:56:54","pageview",2,3888797002525748,10653978521204310672,"plausible.io","/login","","","FI","Desktop","Windows","Chrome","","","","['logged_in']","['false']","120.0","10","FI-11","",634963,"","",\\N,"   ",\\N,"   "
      "2024-01-02 07:57:33","pageview",2,3888797002525748,10653978521204310672,"plausible.io","/activate","","","FI","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","FI-11","",634963,"","",\\N,"   ",\\N,"   "
      "2024-01-02 07:57:33","pageview",2,3888797002525748,10653978521204310672,"plausible.io","/activate","","","FI","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","FI-11","",634963,"","",\\N,"   ",\\N,"   "
      "2024-01-02 07:58:10","pageview",2,3888797002525748,10653978521204310672,"plausible.io","/activate","","","FI","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","FI-11","",634963,"","",\\N,"   ",\\N,"   "
      "2024-01-02 07:58:10","pageview",2,3888797002525748,10653978521204310672,"plausible.io","/activate","","","FI","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","FI-11","",634963,"","",\\N,"   ",\\N,"   "
      "2024-01-02 07:58:45","pageview",2,3888797002525748,10653978521204310672,"plausible.io","/sites","","","FI","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","FI-11","",634963,"","",\\N,"   ",\\N,"   "
      "2024-01-02 07:58:45","pageview",2,3888797002525748,10653978521204310672,"plausible.io","/sites","","","FI","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","FI-11","",634963,"","",\\N,"   ",\\N,"   "
      "2024-01-02 07:59:20","pageview",2,3888797002525748,10653978521204310672,"plausible.io","/:dashboard","","","FI","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","FI-11","",634963,"","",\\N,"   ",\\N,"   "
      "2024-01-02 07:59:20","pageview",2,3888797002525748,10653978521204310672,"plausible.io","/:dashboard","","","FI","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","FI-11","",634963,"","",\\N,"   ",\\N,"   "
      "2024-01-02 09:55:20","pageview",2,3888797002525748,2350060660740786254,"plausible.io","/sites","","","FI","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","FI-11","",634963,"","",\\N,"   ",\\N,"   "
      "2024-01-02 09:55:20","pageview",2,3888797002525748,2350060660740786254,"plausible.io","/sites","","","FI","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","FI-11","",634963,"","",\\N,"   ",\\N,"   "
      "2024-01-02 19:25:25","pageview",2,4241359259084596,14907626633242401061,"plausible.io","/:dashboard/settings/visibility","agnesroothaan.com","agnesroothaan.com","NL","Desktop","Mac","Firefox","","","","['logged_in']","['true']","121.0","10.15","","",0,"","",\\N,"   ",\\N,"   "
      "2024-01-02 19:25:25","pageview",2,4241359259084596,14907626633242401061,"plausible.io","/:dashboard/settings/visibility","agnesroothaan.com","agnesroothaan.com","NL","Desktop","Mac","Firefox","","","","['logged_in']","['true']","121.0","10.15","","",0,"","",\\N,"   ",\\N,"   "
      "2024-01-02 19:25:54","pageview",2,4241359259084596,14907626633242401061,"plausible.io","/login","","","NL","Desktop","Mac","Firefox","","","","['logged_in']","['false']","121.0","10.15","","",0,"","",\\N,"   ",\\N,"   "
      "2024-01-02 19:25:55","pageview",2,4241359259084596,14907626633242401061,"plausible.io","/login","","","NL","Desktop","Mac","Firefox","","","","['logged_in']","['false']","121.0","10.15","","",0,"","",\\N,"   ",\\N,"   "
      "2024-01-02 19:25:57","pageview",2,4241359259084596,14907626633242401061,"plausible.io","/sites","","","NL","Desktop","Mac","Firefox","","","","['logged_in']","['true']","121.0","10.15","","",0,"","",\\N,"   ",\\N,"   "
      "2024-01-02 19:25:58","pageview",2,4241359259084596,14907626633242401061,"plausible.io","/sites","","","NL","Desktop","Mac","Firefox","","","","['logged_in']","['true']","121.0","10.15","","",0,"","",\\N,"   ",\\N,"   "
      "2024-01-02 19:26:30","pageview",2,4241359259084596,14907626633242401061,"plausible.io","/:dashboard","","","NL","Desktop","Mac","Firefox","","","","['logged_in']","['true']","121.0","10.15","","",0,"","",\\N,"   ",\\N,"   "
      "2024-01-02 19:26:30","pageview",2,4241359259084596,14907626633242401061,"plausible.io","/:dashboard","","","NL","Desktop","Mac","Firefox","","","","['logged_in']","['true']","121.0","10.15","","",0,"","",\\N,"   ",\\N,"   "
      "2024-01-02 16:24:41","pageview",2,5459917688007592,12587481492654003375,"plausible.io","/","google.com","Google","HU","Mobile","Android","Chrome","","","","[]","[]","120.0","10","HU-PE","",3047647,"","",\\N,"   ",\\N,"   "
      "2024-01-02 16:24:41","pageview",2,5459917688007592,12587481492654003375,"plausible.io","/","google.com","Google","HU","Mobile","Android","Chrome","","","","[]","[]","120.0","10","HU-PE","",3047647,"","",\\N,"   ",\\N,"   "
      "2024-01-02 20:20:57","pageview",2,8281987717848376,18262618460720387360,"plausible.io","/","","","ES","Desktop","GNU/Linux","Chrome","","","","[]","[]","120.0","","ES-CT","ES-B",3112866,"","",\\N,"   ",\\N,"   "
      "2024-01-02 20:20:57","pageview",2,8281987717848376,18262618460720387360,"plausible.io","/","","","ES","Desktop","GNU/Linux","Chrome","","","","[]","[]","120.0","","ES-CT","ES-B",3112866,"","",\\N,"   ",\\N,"   "
      "2024-01-03 15:25:02","pageview",2,1620538236508475,12533098435721363684,"plausible.io","/sites","","","US","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","US-MD","",4351977,"","",\\N,"   ",\\N,"   "
      "2024-01-03 15:25:02","pageview",2,1620538236508475,12533098435721363684,"plausible.io","/sites","","","US","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","US-MD","",4351977,"","",\\N,"   ",\\N,"   "
      "2024-01-03 15:25:05","pageview",2,1620538236508475,12533098435721363684,"plausible.io","/:dashboard","","","US","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","US-MD","",4351977,"","",\\N,"   ",\\N,"   "
      "2024-01-03 15:25:05","pageview",2,1620538236508475,12533098435721363684,"plausible.io","/:dashboard","","","US","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","US-MD","",4351977,"","",\\N,"   ",\\N,"   "
      "2024-01-03 16:14:18","pageview",2,1620538236508475,5827885226956781955,"plausible.io","/sites","","","US","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","US-MD","",4351977,"","",\\N,"   ",\\N,"   "
      "2024-01-03 16:14:18","pageview",2,1620538236508475,5827885226956781955,"plausible.io","/sites","","","US","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","US-MD","",4351977,"","",\\N,"   ",\\N,"   "
      "2024-01-03 16:14:20","pageview",2,1620538236508475,5827885226956781955,"plausible.io","/:dashboard","","","US","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","US-MD","",4351977,"","",\\N,"   ",\\N,"   "
      "2024-01-03 16:14:20","pageview",2,1620538236508475,5827885226956781955,"plausible.io","/:dashboard","","","US","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","US-MD","",4351977,"","",\\N,"   ",\\N,"   "
      "2024-01-03 18:08:12","pageview",2,1620538236508475,14403993981374023970,"plausible.io","/sites","","","US","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","US-MD","",4351977,"","",\\N,"   ",\\N,"   "
      "2024-01-03 18:08:12","pageview",2,1620538236508475,14403993981374023970,"plausible.io","/sites","","","US","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","US-MD","",4351977,"","",\\N,"   ",\\N,"   "
      "2024-01-03 18:08:14","pageview",2,1620538236508475,14403993981374023970,"plausible.io","/:dashboard","","","US","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","US-MD","",4351977,"","",\\N,"   ",\\N,"   "
      "2024-01-03 18:08:14","pageview",2,1620538236508475,14403993981374023970,"plausible.io","/:dashboard","","","US","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","US-MD","",4351977,"","",\\N,"   ",\\N,"   "
      "2024-01-03 14:21:58","pageview",2,1991080545489942,7827721650756309023,"plausible.io","/:dashboard","","","DE","Mobile","iOS","Safari","","","","['logged_in']","['true']","16.6","16.7","DE-HE","",2925533,"","",\\N,"   ",\\N,"   "
      "2024-01-03 14:21:58","pageview",2,1991080545489942,7827721650756309023,"plausible.io","/:dashboard","","","DE","Mobile","iOS","Safari","","","","['logged_in']","['true']","16.6","16.7","DE-HE","",2925533,"","",\\N,"   ",\\N,"   "
      "2024-01-03 14:22:00","pageview",2,1991080545489942,7827721650756309023,"plausible.io","/:dashboard","","","DE","Mobile","iOS","Safari","","","","['logged_in']","['true']","16.6","16.7","DE-HE","",2925533,"","",\\N,"   ",\\N,"   "
      "2024-01-03 14:22:00","pageview",2,1991080545489942,7827721650756309023,"plausible.io","/:dashboard","","","DE","Mobile","iOS","Safari","","","","['logged_in']","['true']","16.6","16.7","DE-HE","",2925533,"","",\\N,"   ",\\N,"   "
      "2024-01-03 14:22:04","pageview",2,1991080545489942,7827721650756309023,"plausible.io","/:dashboard","","","DE","Mobile","iOS","Safari","","","","['logged_in']","['true']","16.6","16.7","DE-HE","",2925533,"","",\\N,"   ",\\N,"   "
      "2024-01-03 14:22:04","pageview",2,1991080545489942,7827721650756309023,"plausible.io","/:dashboard","","","DE","Mobile","iOS","Safari","","","","['logged_in']","['true']","16.6","16.7","DE-HE","",2925533,"","",\\N,"   ",\\N,"   "
      "2024-01-03 11:24:28","pageview",2,2442170009453171,10923252767260442011,"plausible.io","/","google.com","Google","FR","Desktop","Mac","Chrome","","","","[]","[]","119.0","10.15","FR-IDF","FR-92",3012649,"","",\\N,"   ",\\N,"   "
      "2024-01-03 11:24:28","pageview",2,2442170009453171,10923252767260442011,"plausible.io","/","google.com","Google","FR","Desktop","Mac","Chrome","","","","[]","[]","119.0","10.15","FR-IDF","FR-92",3012649,"","",\\N,"   ",\\N,"   "
      "2024-01-03 11:25:52","pageview",2,2442170009453171,10923252767260442011,"plausible.io","/plausible.io","","","FR","Desktop","Mac","Chrome","","","","['logged_in']","['false']","119.0","10.15","FR-IDF","FR-92",3012649,"","",\\N,"   ",\\N,"   "
      "2024-01-03 11:25:52","pageview",2,2442170009453171,10923252767260442011,"plausible.io","/plausible.io","","","FR","Desktop","Mac","Chrome","","","","['logged_in']","['false']","119.0","10.15","FR-IDF","FR-92",3012649,"","",\\N,"   ",\\N,"   "
      "2024-01-03 19:28:22","pageview",2,3567343926552584,12530768248758226381,"plausible.io","/:dashboard","","","US","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","US-DC","",4140963,"","",\\N,"   ",\\N,"   "
      "2024-01-03 19:28:22","pageview",2,3567343926552584,12530768248758226381,"plausible.io","/:dashboard","","","US","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","US-DC","",4140963,"","",\\N,"   ",\\N,"   "
      "2024-01-03 02:38:06","pageview",2,7876703414044630,13701666527546080143,"plausible.io","/","","","SG","Desktop","Windows","Firefox","","","","[]","[]","121.0","10","","",1880252,"","",\\N,"   ",\\N,"   "
      "2024-01-03 02:38:06","pageview",2,7876703414044630,11680188501286356359,"plausible.io","/","","","SG","Desktop","Windows","Firefox","","","","[]","[]","121.0","10","","",1880252,"","",\\N,"   ",\\N,"   "
      "2024-01-04 07:53:33","pageview",2,1386831400952234,7169584723214728062,"plausible.io","/sites","","","PL","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","PL-12","",3094802,"","",\\N,"   ",\\N,"   "
      "2024-01-04 07:53:33","pageview",2,1386831400952234,7169584723214728062,"plausible.io","/sites","","","PL","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","PL-12","",3094802,"","",\\N,"   ",\\N,"   "
      "2024-01-04 07:53:35","pageview",2,1386831400952234,7169584723214728062,"plausible.io","/:dashboard","","","PL","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","PL-12","",3094802,"","",\\N,"   ",\\N,"   "
      "2024-01-04 07:53:35","pageview",2,1386831400952234,7169584723214728062,"plausible.io","/:dashboard","","","PL","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","PL-12","",3094802,"","",\\N,"   ",\\N,"   "
      "2024-01-04 07:54:39","pageview",2,1386831400952234,7169584723214728062,"plausible.io","/sites","","","PL","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","PL-12","",3094802,"","",\\N,"   ",\\N,"   "
      "2024-01-04 07:54:39","pageview",2,1386831400952234,7169584723214728062,"plausible.io","/sites","","","PL","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","PL-12","",3094802,"","",\\N,"   ",\\N,"   "
      "2024-01-04 07:55:59","pageview",2,1386831400952234,7169584723214728062,"plausible.io","/:dashboard","","","PL","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","PL-12","",3094802,"","",\\N,"   ",\\N,"   "
      "2024-01-04 07:55:59","pageview",2,1386831400952234,7169584723214728062,"plausible.io","/:dashboard","","","PL","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","PL-12","",3094802,"","",\\N,"   ",\\N,"   "
      "2024-01-04 08:41:20","pageview",2,1386831400952234,2141028661119851837,"plausible.io","/sites","","","PL","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","PL-12","",3094802,"","",\\N,"   ",\\N,"   "
      "2024-01-04 08:41:20","pageview",2,1386831400952234,2141028661119851837,"plausible.io","/sites","","","PL","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","PL-12","",3094802,"","",\\N,"   ",\\N,"   "
      "2024-01-04 08:41:22","pageview",2,1386831400952234,2141028661119851837,"plausible.io","/:dashboard","","","PL","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","PL-12","",3094802,"","",\\N,"   ",\\N,"   "
      "2024-01-04 08:41:22","pageview",2,1386831400952234,2141028661119851837,"plausible.io","/:dashboard","","","PL","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","PL-12","",3094802,"","",\\N,"   ",\\N,"   "
      "2024-01-04 08:44:30","pageview",2,1386831400952234,2141028661119851837,"plausible.io","/sites","","","PL","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","PL-12","",3094802,"","",\\N,"   ",\\N,"   "
      "2024-01-04 08:44:30","pageview",2,1386831400952234,2141028661119851837,"plausible.io","/sites","","","PL","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","PL-12","",3094802,"","",\\N,"   ",\\N,"   "
      "2024-01-04 08:44:31","pageview",2,1386831400952234,2141028661119851837,"plausible.io","/:dashboard","","","PL","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","PL-12","",3094802,"","",\\N,"   ",\\N,"   "
      "2024-01-04 08:44:31","pageview",2,1386831400952234,2141028661119851837,"plausible.io","/:dashboard","","","PL","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","PL-12","",3094802,"","",\\N,"   ",\\N,"   "
      "2024-01-04 14:18:58","pageview",2,2902752707980008,1470061201078944177,"plausible.io","/login","","","NL","Desktop","Windows","Chrome","","","","['logged_in']","['false']","120.0","10","NL-UT","",2753908,"","",\\N,"   ",\\N,"   "
      "2024-01-04 14:19:03","pageview",2,2902752707980008,1470061201078944177,"plausible.io","/sites","","","NL","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","NL-UT","",2753908,"","",\\N,"   ",\\N,"   "
      "2024-01-04 14:19:09","pageview",2,2902752707980008,1470061201078944177,"plausible.io","/:dashboard","","","NL","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","NL-UT","",2753908,"","",\\N,"   ",\\N,"   "
      "2024-01-04 14:19:23","pageview",2,2902752707980008,1470061201078944177,"plausible.io","/:dashboard/settings/general","","","NL","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","NL-UT","",2753908,"","",\\N,"   ",\\N,"   "
      "2024-01-04 14:19:24","pageview",2,2902752707980008,1470061201078944177,"plausible.io","/:dashboard/settings/people","","","NL","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","NL-UT","",2753908,"","",\\N,"   ",\\N,"   "
      "2024-01-04 14:19:29","pageview",2,2902752707980008,1470061201078944177,"plausible.io","/:dashboard/settings/general","","","NL","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","NL-UT","",2753908,"","",\\N,"   ",\\N,"   "
      "2024-01-04 14:19:30","pageview",2,2902752707980008,1470061201078944177,"plausible.io","/:dashboard/settings/general","","","NL","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","NL-UT","",2753908,"","",\\N,"   ",\\N,"   "
      "2024-01-04 14:19:32","pageview",2,2902752707980008,1470061201078944177,"plausible.io","/:dashboard/settings/visibility","","","NL","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","NL-UT","",2753908,"","",\\N,"   ",\\N,"   "
      "2024-01-04 14:20:33","pageview",2,2902752707980008,1470061201078944177,"plausible.io","/:dashboard/settings/people","","","NL","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","NL-UT","",2753908,"","",\\N,"   ",\\N,"   "
      "2024-01-04 14:21:07","pageview",2,2902752707980008,1470061201078944177,"plausible.io","/:dashboard/settings/people","","","NL","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","NL-UT","",2753908,"","",\\N,"   ",\\N,"   "
      "2024-01-04 14:21:13","pageview",2,2902752707980008,1470061201078944177,"plausible.io","/:dashboard/settings/integrations","","","NL","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","NL-UT","",2753908,"","",\\N,"   ",\\N,"   "
      "2024-01-04 14:21:19","pageview",2,2902752707980008,1470061201078944177,"plausible.io","/:dashboard/settings/general","","","NL","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","NL-UT","",2753908,"","",\\N,"   ",\\N,"   "
      "2024-01-04 14:21:22","pageview",2,2902752707980008,1470061201078944177,"plausible.io","/:dashboard/settings/visibility","","","NL","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","NL-UT","",2753908,"","",\\N,"   ",\\N,"   "
      "2024-01-04 14:21:23","pageview",2,2902752707980008,1470061201078944177,"plausible.io","/:dashboard/settings/people","","","NL","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","NL-UT","",2753908,"","",\\N,"   ",\\N,"   "
      "2024-01-04 14:21:25","pageview",2,2902752707980008,1470061201078944177,"plausible.io","/:dashboard/settings/funnels","","","NL","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","NL-UT","",2753908,"","",\\N,"   ",\\N,"   "
      "2024-01-04 14:21:30","pageview",2,2902752707980008,1470061201078944177,"plausible.io","/:dashboard/settings/properties","","","NL","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","NL-UT","",2753908,"","",\\N,"   ",\\N,"   "
      "2024-01-04 14:21:32","pageview",2,2902752707980008,1470061201078944177,"plausible.io","/:dashboard/settings/integrations","","","NL","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","NL-UT","",2753908,"","",\\N,"   ",\\N,"   "
      "2024-01-04 14:21:35","pageview",2,2902752707980008,1470061201078944177,"plausible.io","/:dashboard/settings/email-reports","","","NL","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","NL-UT","",2753908,"","",\\N,"   ",\\N,"   "
      "2024-01-04 14:21:35","pageview",2,2902752707980008,1470061201078944177,"plausible.io","/:dashboard/settings/danger-zone","","","NL","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","NL-UT","",2753908,"","",\\N,"   ",\\N,"   "
      "2024-01-04 14:21:36","pageview",2,2902752707980008,1470061201078944177,"plausible.io","/:dashboard/settings/integrations","","","NL","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","NL-UT","",2753908,"","",\\N,"   ",\\N,"   "
      "2024-01-04 14:21:49","pageview",2,2902752707980008,1470061201078944177,"plausible.io","/:dashboard/settings/general","","","NL","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","NL-UT","",2753908,"","",\\N,"   ",\\N,"   "
      "2024-01-04 14:21:52","pageview",2,2902752707980008,1470061201078944177,"plausible.io","/sites","","","NL","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","NL-UT","",2753908,"","",\\N,"   ",\\N,"   "
      "2024-01-04 14:21:54","pageview",2,2902752707980008,1470061201078944177,"plausible.io","/:dashboard","","","NL","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","NL-UT","",2753908,"","",\\N,"   ",\\N,"   "
      "2024-01-04 14:23:28","pageview",2,2902752707980008,1470061201078944177,"plausible.io","/:dashboard/settings/general","","","NL","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","NL-UT","",2753908,"","",\\N,"   ",\\N,"   "
      "2024-01-04 19:09:43","pageview",2,3608876477749321,14319406160426541547,"plausible.io","/docs/self-hosting-configuration","google.com","Google","US","Desktop","GNU/Linux","Chrome","","","","[]","[]","120.0","","US-MN","",5037649,"","",\\N,"   ",\\N,"   "
      "2024-01-04 19:09:44","pageview",2,3608876477749321,14319406160426541547,"plausible.io","/docs/self-hosting-configuration","google.com","Google","US","Desktop","GNU/Linux","Chrome","","","","[]","[]","120.0","","US-MN","",5037649,"","",\\N,"   ",\\N,"   "
      "2024-01-04 13:57:38","pageview",2,6809697864904680,11460673895771375827,"plausible.io","/","","","CZ","Desktop","Windows","Chrome","","","","[]","[]","120.0","10","CZ-80","CZ-806",3068799,"","",\\N,"   ",\\N,"   "
      "2024-01-05 02:31:19","pageview",2,2669285517751856,9978989278393247774,"plausible.io","/sites","","","US","Mobile","iOS","Safari","","","","['logged_in']","['true']","17.1","17.1","US-FL","",4164143,"","",\\N,"   ",\\N,"   "
      "2024-01-05 02:31:19","pageview",2,2669285517751856,9978989278393247774,"plausible.io","/sites","","","US","Mobile","iOS","Safari","","","","['logged_in']","['true']","17.1","17.1","US-FL","",4164143,"","",\\N,"   ",\\N,"   "
      "2024-01-05 02:31:20","pageview",2,2669285517751856,9978989278393247774,"plausible.io","/login","","","US","Mobile","iOS","Safari","","","","['logged_in']","['false']","17.1","17.1","US-FL","",4164143,"","",\\N,"   ",\\N,"   "
      "2024-01-05 02:31:20","pageview",2,2669285517751856,9978989278393247774,"plausible.io","/login","","","US","Mobile","iOS","Safari","","","","['logged_in']","['false']","17.1","17.1","US-FL","",4164143,"","",\\N,"   ",\\N,"   "
      "2024-01-05 02:31:21","pageview",2,2669285517751856,9978989278393247774,"plausible.io","/login","","","US","Mobile","iOS","Safari","","","","['logged_in']","['false']","17.1","17.1","US-FL","",4164143,"","",\\N,"   ",\\N,"   "
      "2024-01-05 02:31:21","pageview",2,2669285517751856,9978989278393247774,"plausible.io","/login","","","US","Mobile","iOS","Safari","","","","['logged_in']","['false']","17.1","17.1","US-FL","",4164143,"","",\\N,"   ",\\N,"   "
      "2024-01-05 15:21:15","pageview",2,3463383581825712,9201278843536007283,"plausible.io","/sites","","","GB","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","GB-ENG","GB-LEC",2643567,"","",\\N,"   ",\\N,"   "
      "2024-01-05 15:21:15","pageview",2,3463383581825712,9201278843536007283,"plausible.io","/sites","","","GB","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","GB-ENG","GB-LEC",2643567,"","",\\N,"   ",\\N,"   "
      "2024-01-05 20:15:33","pageview",2,3463383581825712,13676620482053998436,"plausible.io","/sites","","","GB","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","GB-ENG","GB-LEC",2643567,"","",\\N,"   ",\\N,"   "
      "2024-01-05 20:15:33","pageview",2,3463383581825712,13676620482053998436,"plausible.io","/sites","","","GB","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","GB-ENG","GB-LEC",2643567,"","",\\N,"   ",\\N,"   "
      "2024-01-05 13:17:05","pageview",2,4757581401924555,15921980883715613085,"plausible.io","/","google.com","Google","SK","Desktop","Windows","Chrome","","","","[]","[]","120.0","10","SK-BL","",3060972,"","",\\N,"   ",\\N,"   "
      "2024-01-05 13:17:05","pageview",2,4757581401924555,15921980883715613085,"plausible.io","/","google.com","Google","SK","Desktop","Windows","Chrome","","","","[]","[]","120.0","10","SK-BL","",3060972,"","",\\N,"   ",\\N,"   "
      "2024-01-05 20:12:41","pageview",2,7052025517906368,808838754918763907,"plausible.io","/:dashboard","","","DE","Mobile","iOS","Safari","","","","['logged_in']","['true']","16.6","16.7","DE-TH","",2831276,"","",\\N,"   ",\\N,"   "
      "2024-01-05 20:12:42","pageview",2,7052025517906368,808838754918763907,"plausible.io","/:dashboard","","","DE","Mobile","iOS","Safari","","","","['logged_in']","['true']","16.6","16.7","DE-TH","",2831276,"","",\\N,"   ",\\N,"   "
      "2024-01-05 20:12:44","pageview",2,7052025517906368,808838754918763907,"plausible.io","/:dashboard","","","DE","Mobile","iOS","Safari","","","","['logged_in']","['true']","16.6","16.7","DE-TH","",2831276,"","",\\N,"   ",\\N,"   "
      "2024-01-05 20:12:44","pageview",2,7052025517906368,808838754918763907,"plausible.io","/:dashboard","","","DE","Mobile","iOS","Safari","","","","['logged_in']","['true']","16.6","16.7","DE-TH","",2831276,"","",\\N,"   ",\\N,"   "
      "2024-01-05 21:06:37","pageview",2,8063314897767234,17003323142756615129,"plausible.io","/:dashboard","","","US","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","US-FL","",4164138,"","",\\N,"   ",\\N,"   "
      "2024-01-05 21:06:38","pageview",2,8063314897767234,17003323142756615129,"plausible.io","/:dashboard","","","US","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","US-FL","",4164138,"","",\\N,"   ",\\N,"   "
      "2024-01-06 13:31:16","pageview",2,2674567519747343,17555898823972588247,"plausible.io","/sites","","","PK","Desktop","Mac","Chrome","","","","['logged_in']","['true']","119.0","10.15","PK-PB","",1172451,"","",\\N,"   ",\\N,"   "
      "2024-01-06 13:31:16","pageview",2,2674567519747343,17555898823972588247,"plausible.io","/sites","","","PK","Desktop","Mac","Chrome","","","","['logged_in']","['true']","119.0","10.15","PK-PB","",1172451,"","",\\N,"   ",\\N,"   "
      "2024-01-06 05:16:04","pageview",2,4905999763529676,2152344308278295085,"plausible.io","/","youtube.com","Youtube","AU","Desktop","Windows","Chrome","","","","[]","[]","120.0","10","AU-VIC","",2158177,"","",\\N,"   ",\\N,"   "
      "2024-01-06 05:16:04","pageview",2,4905999763529676,2152344308278295085,"plausible.io","/","youtube.com","Youtube","AU","Desktop","Windows","Chrome","","","","[]","[]","120.0","10","AU-VIC","",2158177,"","",\\N,"   ",\\N,"   "
      "2024-01-06 05:16:27","pageview",2,4905999763529676,2152344308278295085,"plausible.io","/register","","","AU","Desktop","Windows","Chrome","","","","['logged_in']","['false']","120.0","10","AU-VIC","",2158177,"","",\\N,"   ",\\N,"   "
      "2024-01-06 05:16:27","pageview",2,4905999763529676,2152344308278295085,"plausible.io","/register","","","AU","Desktop","Windows","Chrome","","","","['logged_in']","['false']","120.0","10","AU-VIC","",2158177,"","",\\N,"   ",\\N,"   "
      "2024-01-06 05:16:28","pageview",2,4905999763529676,2152344308278295085,"plausible.io","/","youtube.com","Youtube","AU","Desktop","Windows","Chrome","","","","[]","[]","120.0","10","AU-VIC","",2158177,"","",\\N,"   ",\\N,"   "
      "2024-01-06 05:16:28","pageview",2,4905999763529676,2152344308278295085,"plausible.io","/","youtube.com","Youtube","AU","Desktop","Windows","Chrome","","","","[]","[]","120.0","10","AU-VIC","",2158177,"","",\\N,"   ",\\N,"   "
      "2024-01-06 07:58:06","pageview",2,8569605319906646,11890601100179268661,"plausible.io","/:dashboard","","","FR","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","","",0,"","",\\N,"   ",\\N,"   "
      "2024-01-06 07:58:06","pageview",2,8569605319906646,11890601100179268661,"plausible.io","/:dashboard","","","FR","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","","",0,"","",\\N,"   ",\\N,"   "
      "2024-01-06 08:49:24","pageview",2,8569605319906646,11985629085256425332,"plausible.io","/:dashboard","","","FR","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","","",0,"","",\\N,"   ",\\N,"   "
      "2024-01-06 08:49:24","pageview",2,8569605319906646,11985629085256425332,"plausible.io","/:dashboard","","","FR","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","","",0,"","",\\N,"   ",\\N,"   "
      "2024-01-06 09:07:40","pageview",2,8569605319906646,11985629085256425332,"plausible.io","/:dashboard","","","FR","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","","",0,"","",\\N,"   ",\\N,"   "
      "2024-01-06 09:07:40","pageview",2,8569605319906646,11985629085256425332,"plausible.io","/:dashboard","","","FR","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","","",0,"","",\\N,"   ",\\N,"   "
      "2024-01-06 10:53:49","pageview",2,8569605319906646,14087710344798001358,"plausible.io","/:dashboard","","","FR","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","","",0,"","",\\N,"   ",\\N,"   "
      "2024-01-06 10:53:49","pageview",2,8569605319906646,14087710344798001358,"plausible.io","/:dashboard","","","FR","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","","",0,"","",\\N,"   ",\\N,"   "
      "2024-01-06 11:32:20","pageview",2,8569605319906646,11822674518987888234,"plausible.io","/:dashboard","","","FR","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","","",0,"","",\\N,"   ",\\N,"   "
      "2024-01-06 11:32:20","pageview",2,8569605319906646,11822674518987888234,"plausible.io","/:dashboard","","","FR","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","","",0,"","",\\N,"   ",\\N,"   "
      "2024-01-06 12:44:07","pageview",2,8569605319906646,17876788823258832237,"plausible.io","/:dashboard","","","FR","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","","",0,"","",\\N,"   ",\\N,"   "
      "2024-01-06 12:44:07","pageview",2,8569605319906646,17876788823258832237,"plausible.io","/:dashboard","","","FR","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","","",0,"","",\\N,"   ",\\N,"   "
      "2024-01-07 23:29:09","pageview",2,1013778694548289,2046772439473350003,"plausible.io","/:dashboard","github.com","GitHub","US","Desktop","Windows","Microsoft Edge","","","","['logged_in']","['false']","120.0","10","US-WA","",5800112,"","",\\N,"   ",\\N,"   "
      "2024-01-07 23:29:09","pageview",2,1013778694548289,2046772439473350003,"plausible.io","/:dashboard","github.com","GitHub","US","Desktop","Windows","Microsoft Edge","","","","['logged_in']","['false']","120.0","10","US-WA","",5800112,"","",\\N,"   ",\\N,"   "
      "2024-01-07 14:38:17","pageview",2,3964598939404401,11034410302316631842,"plausible.io","/:dashboard","","","GB","Mobile","iOS","Safari","","","","['logged_in']","['true']","17.1","17.1","GB-ENG","GB-RUT",2641128,"","",\\N,"   ",\\N,"   "
      "2024-01-07 14:38:18","pageview",2,3964598939404401,11034410302316631842,"plausible.io","/:dashboard","","","GB","Mobile","iOS","Safari","","","","['logged_in']","['true']","17.1","17.1","GB-ENG","GB-RUT",2641128,"","",\\N,"   ",\\N,"   "
      "2024-01-07 14:46:34","pageview",2,3964598939404401,11034410302316631842,"plausible.io","/:dashboard","","","GB","Mobile","iOS","Safari","","","","['logged_in']","['true']","17.1","17.1","GB-ENG","GB-RUT",2641128,"","",\\N,"   ",\\N,"   "
      "2024-01-07 14:46:34","pageview",2,3964598939404401,11034410302316631842,"plausible.io","/:dashboard","","","GB","Mobile","iOS","Safari","","","","['logged_in']","['true']","17.1","17.1","GB-ENG","GB-RUT",2641128,"","",\\N,"   ",\\N,"   "
      "2024-01-08 08:39:21","pageview",2,319436247539751,10608108878218856706,"plausible.io","/sites","","","DK","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","DK-84","",2621942,"","",\\N,"   ",\\N,"   "
      "2024-01-08 08:39:21","pageview",2,319436247539751,15765385095703529711,"plausible.io","/sites","","","DK","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","DK-84","",2621942,"","",\\N,"   ",\\N,"   "
      "2024-01-08 10:48:09","pageview",2,319436247539751,4023629694253364848,"plausible.io","/sites","","","DK","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","DK-84","",2621942,"","",\\N,"   ",\\N,"   "
      "2024-01-08 10:48:09","pageview",2,319436247539751,4023629694253364848,"plausible.io","/sites","","","DK","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","DK-84","",2621942,"","",\\N,"   ",\\N,"   "
      "2024-01-08 03:22:00","pageview",2,1262842032889677,10383471554513738829,"plausible.io","/sites","","","US","Mobile","Android","Chrome","","","","['logged_in']","['true']","121.0","10","US-WA","",5809844,"","",\\N,"   ",\\N,"   "
      "2024-01-08 03:22:00","pageview",2,1262842032889677,10383471554513738829,"plausible.io","/sites","","","US","Mobile","Android","Chrome","","","","['logged_in']","['true']","121.0","10","US-WA","",5809844,"","",\\N,"   ",\\N,"   "
      "2024-01-08 03:22:06","pageview",2,1262842032889677,10383471554513738829,"plausible.io","/:dashboard","","","US","Mobile","Android","Chrome","","","","['logged_in']","['true']","121.0","10","US-WA","",5809844,"","",\\N,"   ",\\N,"   "
      "2024-01-08 03:22:06","pageview",2,1262842032889677,10383471554513738829,"plausible.io","/:dashboard","","","US","Mobile","Android","Chrome","","","","['logged_in']","['true']","121.0","10","US-WA","",5809844,"","",\\N,"   ",\\N,"   "
      "2024-01-08 15:01:54","pageview",2,1491841464516787,16514624428580207244,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 15:01:55","pageview",2,1491841464516787,16514624428580207244,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 15:02:13","pageview",2,1491841464516787,16514624428580207244,"plausible.io","/sites","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 15:02:16","pageview",2,1491841464516787,16514624428580207244,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 15:02:25","pageview",2,1491841464516787,16514624428580207244,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 15:02:26","pageview",2,1491841464516787,16514624428580207244,"plausible.io","/sites","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 15:02:28","pageview",2,1491841464516787,16514624428580207244,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 15:02:31","pageview",2,1491841464516787,16514624428580207244,"plausible.io","/sites","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 15:02:33","pageview",2,1491841464516787,16514624428580207244,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 15:02:37","pageview",2,1491841464516787,16514624428580207244,"plausible.io","/sites","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 15:04:00","pageview",2,1491841464516787,16514624428580207244,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 15:08:15","pageview",2,1491841464516787,16514624428580207244,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 15:51:27","pageview",2,1491841464516787,317176108081521816,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 15:51:28","pageview",2,1491841464516787,317176108081521816,"plausible.io","/sites","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 15:51:31","pageview",2,1491841464516787,317176108081521816,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 16:04:32","pageview",2,1491841464516787,317176108081521816,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 17:04:19","pageview",2,1491841464516787,16485025429768064611,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 17:05:10","pageview",2,1491841464516787,16485025429768064611,"plausible.io","/sites","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 17:05:13","pageview",2,1491841464516787,16485025429768064611,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 17:49:05","pageview",2,1491841464516787,5721483021860695203,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 17:49:05","pageview",2,1491841464516787,5721483021860695203,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 18:01:54","pageview",2,1491841464516787,5721483021860695203,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 18:01:54","pageview",2,1491841464516787,5721483021860695203,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 18:01:55","pageview",2,1491841464516787,5721483021860695203,"plausible.io","/sites","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 18:01:55","pageview",2,1491841464516787,5721483021860695203,"plausible.io","/sites","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 18:01:58","pageview",2,1491841464516787,5721483021860695203,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 18:01:58","pageview",2,1491841464516787,5721483021860695203,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 18:01:59","pageview",2,1491841464516787,5721483021860695203,"plausible.io","/sites","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 18:01:59","pageview",2,1491841464516787,5721483021860695203,"plausible.io","/sites","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 18:02:01","pageview",2,1491841464516787,5721483021860695203,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 18:02:01","pageview",2,1491841464516787,5721483021860695203,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 18:03:35","pageview",2,1491841464516787,5721483021860695203,"plausible.io","/sites","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 18:03:35","pageview",2,1491841464516787,5721483021860695203,"plausible.io","/sites","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 18:17:04","pageview",2,1491841464516787,5721483021860695203,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 18:17:04","pageview",2,1491841464516787,5721483021860695203,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 18:17:33","pageview",2,1491841464516787,5721483021860695203,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 18:17:33","pageview",2,1491841464516787,5721483021860695203,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 18:31:26","pageview",2,1491841464516787,5721483021860695203,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 18:31:26","pageview",2,1491841464516787,5721483021860695203,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 20:29:18","pageview",2,1491841464516787,1163026024766963146,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 20:29:18","pageview",2,1491841464516787,1163026024766963146,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 20:40:08","pageview",2,1491841464516787,1163026024766963146,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 20:40:08","pageview",2,1491841464516787,1163026024766963146,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 20:55:28","pageview",2,1491841464516787,1163026024766963146,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 20:55:28","pageview",2,1491841464516787,1163026024766963146,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 21:48:44","pageview",2,1491841464516787,11216009315276519478,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 21:48:44","pageview",2,1491841464516787,11216009315276519478,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 21:48:50","pageview",2,1491841464516787,11216009315276519478,"plausible.io","/sites","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 21:48:50","pageview",2,1491841464516787,11216009315276519478,"plausible.io","/sites","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 21:48:52","pageview",2,1491841464516787,11216009315276519478,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 21:48:52","pageview",2,1491841464516787,11216009315276519478,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 21:48:55","pageview",2,1491841464516787,11216009315276519478,"plausible.io","/sites","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 21:48:55","pageview",2,1491841464516787,11216009315276519478,"plausible.io","/sites","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 21:48:58","pageview",2,1491841464516787,11216009315276519478,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 21:48:58","pageview",2,1491841464516787,11216009315276519478,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 21:49:04","pageview",2,1491841464516787,11216009315276519478,"plausible.io","/sites","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 21:49:04","pageview",2,1491841464516787,11216009315276519478,"plausible.io","/sites","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 22:01:15","pageview",2,1491841464516787,11216009315276519478,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 22:01:15","pageview",2,1491841464516787,11216009315276519478,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 22:20:16","pageview",2,1491841464516787,11216009315276519478,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 22:20:16","pageview",2,1491841464516787,11216009315276519478,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Chrome","","","","['logged_in']","['true']","120.0","16.1","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-08 14:05:12","pageview",2,2846916618357090,11477473954404184805,"plausible.io","/sites","","","HR","Mobile","iOS","Safari","","","","['logged_in']","['true']","16.1","16.1","HR-05","",3188383,"","",\\N,"   ",\\N,"   "
      "2024-01-08 14:05:12","pageview",2,2846916618357090,11477473954404184805,"plausible.io","/sites","","","HR","Mobile","iOS","Safari","","","","['logged_in']","['true']","16.1","16.1","HR-05","",3188383,"","",\\N,"   ",\\N,"   "
      "2024-01-08 14:05:14","pageview",2,2846916618357090,11477473954404184805,"plausible.io","/:dashboard","","","HR","Mobile","iOS","Safari","","","","['logged_in']","['true']","16.1","16.1","HR-05","",3188383,"","",\\N,"   ",\\N,"   "
      "2024-01-08 14:05:14","pageview",2,2846916618357090,11477473954404184805,"plausible.io","/:dashboard","","","HR","Mobile","iOS","Safari","","","","['logged_in']","['true']","16.1","16.1","HR-05","",3188383,"","",\\N,"   ",\\N,"   "
      "2024-01-08 14:06:03","pageview",2,2846916618357090,11477473954404184805,"plausible.io","/:dashboard","","","HR","Mobile","iOS","Safari","","","","['logged_in']","['true']","16.1","16.1","HR-05","",3188383,"","",\\N,"   ",\\N,"   "
      "2024-01-08 14:06:03","pageview",2,2846916618357090,11477473954404184805,"plausible.io","/:dashboard","","","HR","Mobile","iOS","Safari","","","","['logged_in']","['true']","16.1","16.1","HR-05","",3188383,"","",\\N,"   ",\\N,"   "
      "2024-01-08 16:16:41","pageview",2,2846916618357090,13674329651601068563,"plausible.io","/:dashboard","","","HR","Mobile","iOS","Safari","","","","['logged_in']","['true']","16.1","16.1","HR-05","",3188383,"","",\\N,"   ",\\N,"   "
      "2024-01-08 16:16:41","pageview",2,2846916618357090,13674329651601068563,"plausible.io","/:dashboard","","","HR","Mobile","iOS","Safari","","","","['logged_in']","['true']","16.1","16.1","HR-05","",3188383,"","",\\N,"   ",\\N,"   "
      "2024-01-08 18:33:40","pageview",2,2846916618357090,11622063005157845266,"plausible.io","/sites","","","HR","Mobile","iOS","Safari","","","","['logged_in']","['true']","16.1","16.1","HR-05","",3188383,"","",\\N,"   ",\\N,"   "
      "2024-01-08 18:33:40","pageview",2,2846916618357090,11622063005157845266,"plausible.io","/sites","","","HR","Mobile","iOS","Safari","","","","['logged_in']","['true']","16.1","16.1","HR-05","",3188383,"","",\\N,"   ",\\N,"   "
      "2024-01-08 18:33:44","pageview",2,2846916618357090,11622063005157845266,"plausible.io","/:dashboard","","","HR","Mobile","iOS","Safari","","","","['logged_in']","['true']","16.1","16.1","HR-05","",3188383,"","",\\N,"   ",\\N,"   "
      "2024-01-08 18:33:44","pageview",2,2846916618357090,11622063005157845266,"plausible.io","/:dashboard","","","HR","Mobile","iOS","Safari","","","","['logged_in']","['true']","16.1","16.1","HR-05","",3188383,"","",\\N,"   ",\\N,"   "
      "2024-01-08 09:30:12","pageview",2,5222702184143432,3166433125635228690,"plausible.io","/sites","","","JP","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","JP-13","",1850147,"","",\\N,"   ",\\N,"   "
      "2024-01-08 09:30:12","pageview",2,5222702184143432,3166433125635228690,"plausible.io","/sites","","","JP","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","JP-13","",1850147,"","",\\N,"   ",\\N,"   "
      "2024-01-08 09:30:16","pageview",2,5222702184143432,3166433125635228690,"plausible.io","/:dashboard","","","JP","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","JP-13","",1850147,"","",\\N,"   ",\\N,"   "
      "2024-01-08 09:30:16","pageview",2,5222702184143432,3166433125635228690,"plausible.io","/:dashboard","","","JP","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","JP-13","",1850147,"","",\\N,"   ",\\N,"   "
      "2024-01-08 09:32:10","pageview",2,5222702184143432,3166433125635228690,"plausible.io","/sites","","","JP","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","JP-13","",1850147,"","",\\N,"   ",\\N,"   "
      "2024-01-08 09:32:10","pageview",2,5222702184143432,3166433125635228690,"plausible.io","/sites","","","JP","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","JP-13","",1850147,"","",\\N,"   ",\\N,"   "
      "2024-01-08 22:40:48","pageview",2,5222702184143432,4569763345927955250,"plausible.io","/sites","","","JP","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","JP-13","",1850147,"","",\\N,"   ",\\N,"   "
      "2024-01-08 22:40:48","pageview",2,5222702184143432,4569763345927955250,"plausible.io","/sites","","","JP","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","JP-13","",1850147,"","",\\N,"   ",\\N,"   "
      "2024-01-08 22:40:50","pageview",2,5222702184143432,4569763345927955250,"plausible.io","/:dashboard","","","JP","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","JP-13","",1850147,"","",\\N,"   ",\\N,"   "
      "2024-01-08 22:40:50","pageview",2,5222702184143432,4569763345927955250,"plausible.io","/:dashboard","","","JP","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","JP-13","",1850147,"","",\\N,"   ",\\N,"   "
      "2024-01-08 23:57:15","pageview",2,5222702184143432,6181469944402161036,"plausible.io","/sites","","","JP","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","JP-13","",1850147,"","",\\N,"   ",\\N,"   "
      "2024-01-08 23:57:15","pageview",2,5222702184143432,6181469944402161036,"plausible.io","/sites","","","JP","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","JP-13","",1850147,"","",\\N,"   ",\\N,"   "
      "2024-01-09 03:01:16","pageview",2,4882350962611626,15600927922278337000,"plausible.io","/:dashboard","","","US","Mobile","iOS","Safari","","","","['logged_in']","['true']","17.2","17.2","US-NY","",5128581,"","",\\N,"   ",\\N,"   "
      "2024-01-09 03:01:16","pageview",2,4882350962611626,15600927922278337000,"plausible.io","/:dashboard","","","US","Mobile","iOS","Safari","","","","['logged_in']","['true']","17.2","17.2","US-NY","",5128581,"","",\\N,"   ",\\N,"   "
      "2024-01-09 03:01:18","pageview",2,4882350962611626,15600927922278337000,"plausible.io","/:dashboard","","","US","Mobile","iOS","Safari","","","","['logged_in']","['true']","17.2","17.2","US-NY","",5128581,"","",\\N,"   ",\\N,"   "
      "2024-01-09 03:01:18","pageview",2,4882350962611626,15600927922278337000,"plausible.io","/:dashboard","","","US","Mobile","iOS","Safari","","","","['logged_in']","['true']","17.2","17.2","US-NY","",5128581,"","",\\N,"   ",\\N,"   "
      "2024-01-09 18:17:55","pageview",2,5827154319017369,3023318554607489584,"plausible.io","/:dashboard","","","DK","Desktop","Mac","Safari","","","","['logged_in']","['true']","16.5","10.15","DK-82","",2624652,"","",\\N,"   ",\\N,"   "
      "2024-01-09 18:17:55","pageview",2,5827154319017369,3023318554607489584,"plausible.io","/:dashboard","","","DK","Desktop","Mac","Safari","","","","['logged_in']","['true']","16.5","10.15","DK-82","",2624652,"","",\\N,"   ",\\N,"   "
      "2024-01-09 18:18:05","pageview",2,5827154319017369,3023318554607489584,"plausible.io","/:dashboard","","","DK","Desktop","Mac","Safari","","","","['logged_in']","['true']","16.5","10.15","DK-82","",2624652,"","",\\N,"   ",\\N,"   "
      "2024-01-09 18:18:05","pageview",2,5827154319017369,3023318554607489584,"plausible.io","/:dashboard","","","DK","Desktop","Mac","Safari","","","","['logged_in']","['true']","16.5","10.15","DK-82","",2624652,"","",\\N,"   ",\\N,"   "
      "2024-01-09 06:46:18","pageview",2,5836634664072177,17521253752783320192,"plausible.io","/:dashboard","","","GB","Mobile","iOS","Safari","","","","['logged_in']","['true']","16.6","16.6","GB-ENG","GB-WOR",2633563,"","",\\N,"   ",\\N,"   "
      "2024-01-09 06:46:18","pageview",2,5836634664072177,17521253752783320192,"plausible.io","/:dashboard","","","GB","Mobile","iOS","Safari","","","","['logged_in']","['true']","16.6","16.6","GB-ENG","GB-WOR",2633563,"","",\\N,"   ",\\N,"   "
      "2024-01-09 07:23:18","pageview",2,5836634664072177,13797120320504765078,"plausible.io","/:dashboard","","","GB","Mobile","iOS","Safari","","","","['logged_in']","['true']","16.6","16.6","GB-ENG","GB-WOR",2633563,"","",\\N,"   ",\\N,"   "
      "2024-01-09 07:23:18","pageview",2,5836634664072177,13797120320504765078,"plausible.io","/:dashboard","","","GB","Mobile","iOS","Safari","","","","['logged_in']","['true']","16.6","16.6","GB-ENG","GB-WOR",2633563,"","",\\N,"   ",\\N,"   "
      "2024-01-09 13:41:14","pageview",2,6058145466525697,18199445865514564329,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Safari","","","","['logged_in']","['true']","16.3","16.3","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-09 13:41:14","pageview",2,6058145466525697,18199445865514564329,"plausible.io","/:dashboard","","","AT","Mobile","iOS","Safari","","","","['logged_in']","['true']","16.3","16.3","AT-9","",2761369,"","",\\N,"   ",\\N,"   "
      "2024-01-09 08:56:51","pageview",2,8251349988663916,16881781935249629725,"plausible.io","/:dashboard","","","DK","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","DK-82","",2621710,"","",\\N,"   ",\\N,"   "
      "2024-01-09 08:56:51","pageview",2,8251349988663916,16881781935249629725,"plausible.io","/:dashboard","","","DK","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","DK-82","",2621710,"","",\\N,"   ",\\N,"   "
      "2024-01-09 06:56:09","pageview",2,8627663563487652,14522258747882651516,"plausible.io","/:dashboard","","","SE","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.1","10.15","SE-AB","",2673730,"","",\\N,"   ",\\N,"   "
      "2024-01-09 06:56:09","pageview",2,8627663563487652,14522258747882651516,"plausible.io","/:dashboard","","","SE","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.1","10.15","SE-AB","",2673730,"","",\\N,"   ",\\N,"   "
      "2024-01-09 08:09:00","pageview",2,8627663563487652,8879126321530428851,"plausible.io","/:dashboard","","","SE","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.1","10.15","SE-AB","",2673730,"","",\\N,"   ",\\N,"   "
      "2024-01-09 08:09:00","pageview",2,8627663563487652,17479673357660235083,"plausible.io","/:dashboard","","","SE","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.1","10.15","SE-AB","",2673730,"","",\\N,"   ",\\N,"   "
      "2024-01-09 09:02:15","pageview",2,8627663563487652,15441983676622845991,"plausible.io","/:dashboard","","","SE","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.1","10.15","SE-AB","",2673730,"","",\\N,"   ",\\N,"   "
      "2024-01-09 09:02:15","pageview",2,8627663563487652,15441983676622845991,"plausible.io","/:dashboard","","","SE","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.1","10.15","SE-AB","",2673730,"","",\\N,"   ",\\N,"   "
      "2024-01-10 04:36:42","pageview",2,7654343868648363,13105315951801459554,"plausible.io","/:dashboard","","","US","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","US-AZ","",5308655,"","",\\N,"   ",\\N,"   "
      "2024-01-10 04:36:42","pageview",2,7654343868648363,13105315951801459554,"plausible.io","/:dashboard","","","US","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","US-AZ","",5308655,"","",\\N,"   ",\\N,"   "
      "2024-01-10 15:14:36","pageview",2,8428766957603826,15269584988784493510,"plausible.io","/share/:dashboard","","","GB","Desktop","Mac","Chrome","","","","['logged_in']","['false']","120.0","10.15","GB-SCT","GB-EDH",2650225,"","",\\N,"   ",\\N,"   "
      "2024-01-10 15:14:36","pageview",2,8428766957603826,15269584988784493510,"plausible.io","/share/:dashboard","","","GB","Desktop","Mac","Chrome","","","","['logged_in']","['false']","120.0","10.15","GB-SCT","GB-EDH",2650225,"","",\\N,"   ",\\N,"   "
      "2024-01-10 15:51:35","pageview",2,8428766957603826,1205382852325419789,"plausible.io","/share/:dashboard","","","GB","Desktop","Mac","Chrome","","","","['logged_in']","['false']","120.0","10.15","GB-SCT","GB-EDH",2650225,"","",\\N,"   ",\\N,"   "
      "2024-01-10 15:51:35","pageview",2,8428766957603826,1205382852325419789,"plausible.io","/share/:dashboard","","","GB","Desktop","Mac","Chrome","","","","['logged_in']","['false']","120.0","10.15","GB-SCT","GB-EDH",2650225,"","",\\N,"   ",\\N,"   "
      "2024-01-10 05:42:11","pageview",2,8482183136122890,4812257357741602584,"plausible.io","/sites","","","BE","Mobile","iOS","Safari","","","","['logged_in']","['true']","17.2","17.2","BE-BRU","",2800866,"","",\\N,"   ",\\N,"   "
      "2024-01-10 05:42:11","pageview",2,8482183136122890,4812257357741602584,"plausible.io","/sites","","","BE","Mobile","iOS","Safari","","","","['logged_in']","['true']","17.2","17.2","BE-BRU","",2800866,"","",\\N,"   ",\\N,"   "
      "2024-01-11 22:03:41","pageview",2,6095662044207412,1478764090069704746,"plausible.io","/","google.com","Google","GB","Desktop","GNU/Linux","Chrome","","","","[]","[]","115.0","","GB-ENG","GB-ESS",2643160,"","",\\N,"   ",\\N,"   "
      "2024-01-11 22:03:41","pageview",2,6095662044207412,1478764090069704746,"plausible.io","/","google.com","Google","GB","Desktop","GNU/Linux","Chrome","","","","[]","[]","115.0","","GB-ENG","GB-ESS",2643160,"","",\\N,"   ",\\N,"   "
      "2024-01-11 08:29:15","pageview",2,6305215667067726,3650092153238040894,"plausible.io","/:dashboard","","","FR","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","FR-BRE","FR-29",3017624,"","",\\N,"   ",\\N,"   "
      "2024-01-11 20:34:17","pageview",2,7715581262488642,4212029886480057967,"plausible.io","/","google.com","Google","FI","Desktop","Windows","Chrome","","","","[]","[]","120.0","10","FI-19","",637948,"","",\\N,"   ",\\N,"   "
      "2024-01-11 20:34:17","pageview",2,7715581262488642,4212029886480057967,"plausible.io","/","google.com","Google","FI","Desktop","Windows","Chrome","","","","[]","[]","120.0","10","FI-19","",637948,"","",\\N,"   ",\\N,"   "
      "2024-01-11 20:34:50","pageview",2,7715581262488642,4212029886480057967,"plausible.io","/vs-cloudflare-web-analytics","","","FI","Desktop","Windows","Chrome","","","","[]","[]","120.0","10","FI-19","",637948,"","",\\N,"   ",\\N,"   "
      "2024-01-11 20:34:50","pageview",2,7715581262488642,4212029886480057967,"plausible.io","/vs-cloudflare-web-analytics","","","FI","Desktop","Windows","Chrome","","","","[]","[]","120.0","10","FI-19","",637948,"","",\\N,"   ",\\N,"   "
      "2024-01-12 11:10:33","pageview",2,3220646452433704,17662261298038438805,"plausible.io","/sites","","","PT","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","PT-13","",2733249,"","",\\N,"   ",\\N,"   "
      "2024-01-12 11:10:33","pageview",2,3220646452433704,17662261298038438805,"plausible.io","/sites","","","PT","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","PT-13","",2733249,"","",\\N,"   ",\\N,"   "
      "2024-01-12 11:10:36","pageview",2,3220646452433704,17662261298038438805,"plausible.io","/:dashboard","","","PT","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","PT-13","",2733249,"","",\\N,"   ",\\N,"   "
      "2024-01-12 11:10:36","pageview",2,3220646452433704,17662261298038438805,"plausible.io","/:dashboard","","","PT","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","PT-13","",2733249,"","",\\N,"   ",\\N,"   "
      "2024-01-12 11:57:00","pageview",2,3220646452433704,10718621414717637663,"plausible.io","/sites","","","PT","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","PT-13","",2733249,"","",\\N,"   ",\\N,"   "
      "2024-01-12 11:57:00","pageview",2,3220646452433704,10718621414717637663,"plausible.io","/sites","","","PT","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","PT-13","",2733249,"","",\\N,"   ",\\N,"   "
      "2024-01-12 11:57:02","pageview",2,3220646452433704,10718621414717637663,"plausible.io","/:dashboard","","","PT","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","PT-13","",2733249,"","",\\N,"   ",\\N,"   "
      "2024-01-12 11:57:02","pageview",2,3220646452433704,10718621414717637663,"plausible.io","/:dashboard","","","PT","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","PT-13","",2733249,"","",\\N,"   ",\\N,"   "
      "2024-01-12 13:01:07","pageview",2,3220646452433704,14972234457589972545,"plausible.io","/sites","","","PT","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","PT-13","",2733249,"","",\\N,"   ",\\N,"   "
      "2024-01-12 13:01:07","pageview",2,3220646452433704,14972234457589972545,"plausible.io","/sites","","","PT","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","PT-13","",2733249,"","",\\N,"   ",\\N,"   "
      "2024-01-12 13:01:09","pageview",2,3220646452433704,14972234457589972545,"plausible.io","/:dashboard","","","PT","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","PT-13","",2733249,"","",\\N,"   ",\\N,"   "
      "2024-01-12 13:01:09","pageview",2,3220646452433704,14972234457589972545,"plausible.io","/:dashboard","","","PT","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","PT-13","",2733249,"","",\\N,"   ",\\N,"   "
      "2024-01-12 16:17:12","pageview",2,3220646452433704,16233290597231281024,"plausible.io","/sites","","","PT","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","PT-13","",2733249,"","",\\N,"   ",\\N,"   "
      "2024-01-12 16:17:12","pageview",2,3220646452433704,16233290597231281024,"plausible.io","/sites","","","PT","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","PT-13","",2733249,"","",\\N,"   ",\\N,"   "
      "2024-01-12 16:17:13","pageview",2,3220646452433704,16233290597231281024,"plausible.io","/:dashboard","","","PT","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","PT-13","",2733249,"","",\\N,"   ",\\N,"   "
      "2024-01-12 16:17:13","pageview",2,3220646452433704,16233290597231281024,"plausible.io","/:dashboard","","","PT","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","PT-13","",2733249,"","",\\N,"   ",\\N,"   "
      "2024-01-12 16:32:43","pageview",2,3220646452433704,16233290597231281024,"plausible.io","/sites","","","PT","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","PT-13","",2733249,"","",\\N,"   ",\\N,"   "
      "2024-01-12 16:32:43","pageview",2,3220646452433704,16233290597231281024,"plausible.io","/sites","","","PT","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","PT-13","",2733249,"","",\\N,"   ",\\N,"   "
      "2024-01-12 16:32:48","pageview",2,3220646452433704,16233290597231281024,"plausible.io","/:dashboard","","","PT","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","PT-13","",2733249,"","",\\N,"   ",\\N,"   "
      "2024-01-12 16:32:48","pageview",2,3220646452433704,16233290597231281024,"plausible.io","/:dashboard","","","PT","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","PT-13","",2733249,"","",\\N,"   ",\\N,"   "
      "2024-01-12 16:52:00","pageview",2,3220646452433704,16233290597231281024,"plausible.io","/sites","","","PT","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","PT-13","",2733249,"","",\\N,"   ",\\N,"   "
      "2024-01-12 16:52:00","pageview",2,3220646452433704,16233290597231281024,"plausible.io","/sites","","","PT","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","PT-13","",2733249,"","",\\N,"   ",\\N,"   "
      "2024-01-12 16:52:02","pageview",2,3220646452433704,16233290597231281024,"plausible.io","/:dashboard","","","PT","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","PT-13","",2733249,"","",\\N,"   ",\\N,"   "
      "2024-01-12 16:52:02","pageview",2,3220646452433704,16233290597231281024,"plausible.io","/:dashboard","","","PT","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","PT-13","",2733249,"","",\\N,"   ",\\N,"   "
      "2024-01-12 17:10:55","pageview",2,3220646452433704,16233290597231281024,"plausible.io","/sites","","","PT","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","PT-13","",2733249,"","",\\N,"   ",\\N,"   "
      "2024-01-12 17:10:55","pageview",2,3220646452433704,16233290597231281024,"plausible.io","/sites","","","PT","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","PT-13","",2733249,"","",\\N,"   ",\\N,"   "
      "2024-01-12 17:10:57","pageview",2,3220646452433704,16233290597231281024,"plausible.io","/:dashboard","","","PT","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","PT-13","",2733249,"","",\\N,"   ",\\N,"   "
      "2024-01-12 17:10:57","pageview",2,3220646452433704,16233290597231281024,"plausible.io","/:dashboard","","","PT","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","PT-13","",2733249,"","",\\N,"   ",\\N,"   "
      "2024-01-12 17:47:08","pageview",2,3220646452433704,17588140732813363895,"plausible.io","/sites","","","PT","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","PT-13","",2733249,"","",\\N,"   ",\\N,"   "
      "2024-01-12 17:47:08","pageview",2,3220646452433704,9408683463088063451,"plausible.io","/sites","","","PT","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","PT-13","",2733249,"","",\\N,"   ",\\N,"   "
      "2024-01-12 17:47:10","pageview",2,3220646452433704,9408683463088063451,"plausible.io","/:dashboard","","","PT","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","PT-13","",2733249,"","",\\N,"   ",\\N,"   "
      "2024-01-12 17:47:10","pageview",2,3220646452433704,9408683463088063451,"plausible.io","/:dashboard","","","PT","Desktop","Windows","Chrome","","","","['logged_in']","['true']","120.0","10","PT-13","",2733249,"","",\\N,"   ",\\N,"   "
      "2024-01-12 11:07:44","pageview",2,4993417743097898,18109938131442810270,"plausible.io","/sites","","","MK","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","","",785842,"","",\\N,"   ",\\N,"   "
      "2024-01-12 11:07:44","pageview",2,4993417743097898,18109938131442810270,"plausible.io","/sites","","","MK","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","","",785842,"","",\\N,"   ",\\N,"   "
      "2024-01-12 11:07:52","pageview",2,4993417743097898,18109938131442810270,"plausible.io","/:dashboard","","","MK","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","","",785842,"","",\\N,"   ",\\N,"   "
      "2024-01-12 11:07:52","pageview",2,4993417743097898,18109938131442810270,"plausible.io","/:dashboard","","","MK","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","","",785842,"","",\\N,"   ",\\N,"   "
      "2024-01-12 19:59:02","pageview",2,4993417743097898,17945264885979215739,"plausible.io","/sites","","","MK","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","","",785842,"","",\\N,"   ",\\N,"   "
      "2024-01-12 19:59:02","pageview",2,4993417743097898,17945264885979215739,"plausible.io","/sites","","","MK","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","","",785842,"","",\\N,"   ",\\N,"   "
      "2024-01-12 19:59:31","pageview",2,4993417743097898,17945264885979215739,"plausible.io","/:dashboard","","","MK","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","","",785842,"","",\\N,"   ",\\N,"   "
      "2024-01-12 19:59:31","pageview",2,4993417743097898,17945264885979215739,"plausible.io","/:dashboard","","","MK","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","","",785842,"","",\\N,"   ",\\N,"   "
      "2024-01-12 19:59:39","pageview",2,4993417743097898,17945264885979215739,"plausible.io","/sites","","","MK","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","","",785842,"","",\\N,"   ",\\N,"   "
      "2024-01-12 19:59:39","pageview",2,4993417743097898,17945264885979215739,"plausible.io","/sites","","","MK","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","","",785842,"","",\\N,"   ",\\N,"   "
      "2024-01-12 20:00:01","pageview",2,4993417743097898,17945264885979215739,"plausible.io","/:dashboard","","","MK","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","","",785842,"","",\\N,"   ",\\N,"   "
      "2024-01-12 20:00:01","pageview",2,4993417743097898,17945264885979215739,"plausible.io","/:dashboard","","","MK","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","","",785842,"","",\\N,"   ",\\N,"   "
      "2024-01-12 20:00:16","pageview",2,4993417743097898,17945264885979215739,"plausible.io","/sites","","","MK","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","","",785842,"","",\\N,"   ",\\N,"   "
      "2024-01-12 20:00:16","pageview",2,4993417743097898,17945264885979215739,"plausible.io","/sites","","","MK","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","","",785842,"","",\\N,"   ",\\N,"   "
      "2024-01-12 20:00:19","pageview",2,4993417743097898,17945264885979215739,"plausible.io","/:dashboard","","","MK","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","","",785842,"","",\\N,"   ",\\N,"   "
      "2024-01-12 20:00:19","pageview",2,4993417743097898,17945264885979215739,"plausible.io","/:dashboard","","","MK","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","","",785842,"","",\\N,"   ",\\N,"   "
      "2024-01-12 20:00:21","pageview",2,4993417743097898,17945264885979215739,"plausible.io","/sites","","","MK","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","","",785842,"","",\\N,"   ",\\N,"   "
      "2024-01-12 20:00:21","pageview",2,4993417743097898,17945264885979215739,"plausible.io","/sites","","","MK","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","","",785842,"","",\\N,"   ",\\N,"   "
      "2024-01-12 20:00:29","pageview",2,4993417743097898,17945264885979215739,"plausible.io","/:dashboard","","","MK","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","","",785842,"","",\\N,"   ",\\N,"   "
      "2024-01-12 20:00:29","pageview",2,4993417743097898,17945264885979215739,"plausible.io","/:dashboard","","","MK","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","","",785842,"","",\\N,"   ",\\N,"   "
      "2024-01-12 20:02:58","pageview",2,4993417743097898,17945264885979215739,"plausible.io","/:dashboard","","","MK","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","","",785842,"","",\\N,"   ",\\N,"   "
      "2024-01-12 20:02:58","pageview",2,4993417743097898,17945264885979215739,"plausible.io","/:dashboard","","","MK","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","","",785842,"","",\\N,"   ",\\N,"   "
      "2024-01-12 20:04:18","pageview",2,4993417743097898,17945264885979215739,"plausible.io","/vs-cloudflare-web-analytics","","","MK","Desktop","Mac","Safari","","","","[]","[]","17.2","10.15","","",785842,"","",\\N,"   ",\\N,"   "
      "2024-01-12 20:04:18","pageview",2,4993417743097898,17945264885979215739,"plausible.io","/vs-cloudflare-web-analytics","","","MK","Desktop","Mac","Safari","","","","[]","[]","17.2","10.15","","",785842,"","",\\N,"   ",\\N,"   "
      "2024-01-12 09:47:02","pageview",2,5292369883223652,16006747592031739775,"plausible.io","/:dashboard","","","HR","Mobile","iOS","Safari","","","","['logged_in']","['true']","16.1","16.1","HR-21","",0,"","",\\N,"   ",\\N,"   "
      "2024-01-12 09:47:02","pageview",2,5292369883223652,16006747592031739775,"plausible.io","/:dashboard","","","HR","Mobile","iOS","Safari","","","","['logged_in']","['true']","16.1","16.1","HR-21","",0,"","",\\N,"   ",\\N,"   "
      "2024-01-12 13:45:47","pageview",2,6441703167470208,2750043803984928038,"plausible.io","/:dashboard","","","AT","Desktop","Mac","Chrome","","","","['logged_in']","['true']","111.0","10.15","AT-8","",2779674,"","",\\N,"   ",\\N,"   "
      "2024-01-12 13:45:47","pageview",2,6441703167470208,2750043803984928038,"plausible.io","/:dashboard","","","AT","Desktop","Mac","Chrome","","","","['logged_in']","['true']","111.0","10.15","AT-8","",2779674,"","",\\N,"   ",\\N,"   "
      "2024-01-12 13:45:50","pageview",2,6441703167470208,2750043803984928038,"plausible.io","/:dashboard","","","AT","Desktop","Mac","Chrome","","","","['logged_in']","['true']","111.0","10.15","AT-8","",2779674,"","",\\N,"   ",\\N,"   "
      "2024-01-12 13:45:50","pageview",2,6441703167470208,2750043803984928038,"plausible.io","/:dashboard","","","AT","Desktop","Mac","Chrome","","","","['logged_in']","['true']","111.0","10.15","AT-8","",2779674,"","",\\N,"   ",\\N,"   "
      "2024-01-12 13:45:52","pageview",2,6441703167470208,2750043803984928038,"plausible.io","/:dashboard","","","AT","Desktop","Mac","Chrome","","","","['logged_in']","['true']","111.0","10.15","AT-8","",2779674,"","",\\N,"   ",\\N,"   "
      "2024-01-12 13:45:52","pageview",2,6441703167470208,2750043803984928038,"plausible.io","/:dashboard","","","AT","Desktop","Mac","Chrome","","","","['logged_in']","['true']","111.0","10.15","AT-8","",2779674,"","",\\N,"   ",\\N,"   "
      "2024-01-12 13:46:00","pageview",2,6441703167470208,2750043803984928038,"plausible.io","/:dashboard","","","AT","Desktop","Mac","Chrome","","","","['logged_in']","['true']","111.0","10.15","AT-8","",2779674,"","",\\N,"   ",\\N,"   "
      "2024-01-12 13:46:00","pageview",2,6441703167470208,2750043803984928038,"plausible.io","/:dashboard","","","AT","Desktop","Mac","Chrome","","","","['logged_in']","['true']","111.0","10.15","AT-8","",2779674,"","",\\N,"   ",\\N,"   "
      "2024-01-12 13:46:13","pageview",2,6441703167470208,2750043803984928038,"plausible.io","/:dashboard","","","AT","Desktop","Mac","Chrome","","","","['logged_in']","['true']","111.0","10.15","AT-8","",2779674,"","",\\N,"   ",\\N,"   "
      "2024-01-12 13:46:13","pageview",2,6441703167470208,2750043803984928038,"plausible.io","/:dashboard","","","AT","Desktop","Mac","Chrome","","","","['logged_in']","['true']","111.0","10.15","AT-8","",2779674,"","",\\N,"   ",\\N,"   "
      "2024-01-13 09:39:59","pageview",2,2678847443631738,12456905080224463199,"plausible.io","/:dashboard","","","FR","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","FR-OCC","FR-34",2970144,"","",\\N,"   ",\\N,"   "
      "2024-01-13 09:39:59","pageview",2,2678847443631738,12456905080224463199,"plausible.io","/:dashboard","","","FR","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","FR-OCC","FR-34",2970144,"","",\\N,"   ",\\N,"   "
      "2024-01-13 11:04:14","pageview",2,2678847443631738,9855390470565126145,"plausible.io","/:dashboard","","","FR","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","FR-OCC","FR-34",2970144,"","",\\N,"   ",\\N,"   "
      "2024-01-13 11:04:14","pageview",2,2678847443631738,9855390470565126145,"plausible.io","/:dashboard","","","FR","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","FR-OCC","FR-34",2970144,"","",\\N,"   ",\\N,"   "
      "2024-01-13 19:12:14","pageview",2,2678847443631738,17555225793888623733,"plausible.io","/:dashboard","","","FR","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","FR-OCC","FR-34",2970144,"","",\\N,"   ",\\N,"   "
      "2024-01-13 19:12:14","pageview",2,2678847443631738,17555225793888623733,"plausible.io","/:dashboard","","","FR","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","FR-OCC","FR-34",2970144,"","",\\N,"   ",\\N,"   "
      "2024-01-13 19:12:16","pageview",2,2678847443631738,17555225793888623733,"plausible.io","/:dashboard","","","FR","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","FR-OCC","FR-34",2970144,"","",\\N,"   ",\\N,"   "
      "2024-01-13 19:12:16","pageview",2,2678847443631738,17555225793888623733,"plausible.io","/:dashboard","","","FR","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","FR-OCC","FR-34",2970144,"","",\\N,"   ",\\N,"   "
      "2024-01-13 20:33:36","pageview",2,2678847443631738,5543282897613343645,"plausible.io","/:dashboard","","","FR","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","FR-OCC","FR-34",2970144,"","",\\N,"   ",\\N,"   "
      "2024-01-13 20:33:36","pageview",2,2678847443631738,5543282897613343645,"plausible.io","/:dashboard","","","FR","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","FR-OCC","FR-34",2970144,"","",\\N,"   ",\\N,"   "
      "2024-01-13 22:10:51","pageview",2,2678847443631738,6249657084237035719,"plausible.io","/:dashboard","","","FR","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","FR-OCC","FR-34",2970144,"","",\\N,"   ",\\N,"   "
      "2024-01-13 22:10:51","pageview",2,2678847443631738,5060322712081619171,"plausible.io","/:dashboard","","","FR","Desktop","Mac","Safari","","","","['logged_in']","['true']","17.2","10.15","FR-OCC","FR-34",2970144,"","",\\N,"   ",\\N,"   "
      "2024-01-14 17:47:25","pageview",2,7535134733447910,13726673238447225883,"plausible.io","/sites","","","FI","Desktop","Ubuntu","Firefox","","","","['logged_in']","['true']","121.0","","FI-18","",658225,"","",\\N,"   ",\\N,"   "
      "2024-01-14 17:47:25","pageview",2,7535134733447910,13726673238447225883,"plausible.io","/sites","","","FI","Desktop","Ubuntu","Firefox","","","","['logged_in']","['true']","121.0","","FI-18","",658225,"","",\\N,"   ",\\N,"   "
      "2024-01-14 17:47:26","pageview",2,7535134733447910,13726673238447225883,"plausible.io","/login","","","FI","Desktop","Ubuntu","Firefox","","","","['logged_in']","['false']","121.0","","FI-18","",658225,"","",\\N,"   ",\\N,"   "
      "2024-01-14 17:47:26","pageview",2,7535134733447910,13726673238447225883,"plausible.io","/login","","","FI","Desktop","Ubuntu","Firefox","","","","['logged_in']","['false']","121.0","","FI-18","",658225,"","",\\N,"   ",\\N,"   "
      "2024-01-14 17:47:28","pageview",2,7535134733447910,13726673238447225883,"plausible.io","/sites","","","FI","Desktop","Ubuntu","Firefox","","","","['logged_in']","['true']","121.0","","FI-18","",658225,"","",\\N,"   ",\\N,"   "
      "2024-01-14 17:47:28","pageview",2,7535134733447910,13726673238447225883,"plausible.io","/sites","","","FI","Desktop","Ubuntu","Firefox","","","","['logged_in']","['true']","121.0","","FI-18","",658225,"","",\\N,"   ",\\N,"   "
      "2024-01-14 17:47:37","pageview",2,7535134733447910,13726673238447225883,"plausible.io","/sites/new","","","FI","Desktop","Ubuntu","Firefox","","","","['logged_in']","['true']","121.0","","FI-18","",658225,"","",\\N,"   ",\\N,"   "
      "2024-01-14 17:47:37","pageview",2,7535134733447910,13726673238447225883,"plausible.io","/sites/new","","","FI","Desktop","Ubuntu","Firefox","","","","['logged_in']","['true']","121.0","","FI-18","",658225,"","",\\N,"   ",\\N,"   "
      "2024-01-15 08:44:42","pageview",2,74318416938695,5235106120742737722,"plausible.io","/sites","","","FR","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","FR-IDF","FR-75",2988507,"","",\\N,"   ",\\N,"   "
      "2024-01-15 08:44:42","pageview",2,74318416938695,5235106120742737722,"plausible.io","/sites","","","FR","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","FR-IDF","FR-75",2988507,"","",\\N,"   ",\\N,"   "
      "2024-01-15 08:45:09","pageview",2,74318416938695,5235106120742737722,"plausible.io","/:dashboard","","","FR","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","FR-IDF","FR-75",2988507,"","",\\N,"   ",\\N,"   "
      "2024-01-15 08:45:09","pageview",2,74318416938695,5235106120742737722,"plausible.io","/:dashboard","","","FR","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","FR-IDF","FR-75",2988507,"","",\\N,"   ",\\N,"   "
      "2024-01-15 08:45:14","pageview",2,74318416938695,5235106120742737722,"plausible.io","/settings","","","FR","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","FR-IDF","FR-75",2988507,"","",\\N,"   ",\\N,"   "
      "2024-01-15 08:45:14","pageview",2,74318416938695,5235106120742737722,"plausible.io","/settings","","","FR","Desktop","Mac","Chrome","","","","['logged_in']","['true']","120.0","10.15","FR-IDF","FR-75",2988507,"","",\\N,"   ",\\N,"   "
      "2024-01-15 20:31:17","pageview",2,5720971657589925,10385995742944960297,"plausible.io","/login","","","  ","Tablet","iOS","Chrome","","","","['logged_in']","['false']","120.0","17.2","","",0,"","",\\N,"   ",\\N,"   "
      "2024-01-15 20:31:17","pageview",2,5720971657589925,10385995742944960297,"plausible.io","/login","","","  ","Tablet","iOS","Chrome","","","","['logged_in']","['false']","120.0","17.2","","",0,"","",\\N,"   ",\\N,"   "
      "2024-01-15 14:11:22","pageview",2,7985949775551653,16133283732806147076,"plausible.io","/sites","","","MX","Desktop","GNU/Linux","Chrome","","","","['logged_in']","['true']","120.0","","MX-YUC","",3523349,"","",\\N,"   ",\\N,"   "
      "2024-01-23 03:58:00","pageview",2,7284010782363557,8268552482280430197,"plausible.io","/","","","US","Desktop","Mac","Chrome","","","","[]","[]","120.0","10.15","US-CA","",5392171,"","",\\N,"   ",\\N,"   "
      "2024-01-23 03:58:00","pageview",2,7284010782363557,8268552482280430197,"plausible.io","/","","","US","Desktop","Mac","Chrome","","","","[]","[]","120.0","10.15","US-CA","",5392171,"","",\\N,"   ",\\N,"   "
      """

      [header | events_csv] = NimbleCSV.RFC4180.parse_string(events_csv, skip_headers: false)
      idx = Enum.find_index(header, &(&1 == "site_id"))
      events_csv = Enum.map(events_csv, fn row -> List.replace_at(row, idx, site.id) end)
      events_csv = NimbleCSV.RFC4180.dump_to_iodata([header | events_csv])

      [header | sessions_csv] = NimbleCSV.RFC4180.parse_string(sessions_csv, skip_headers: false)
      idx = Enum.find_index(header, &(&1 == "site_id"))
      sessions_csv = Enum.map(sessions_csv, fn row -> List.replace_at(row, idx, site.id) end)
      sessions_csv = NimbleCSV.RFC4180.dump_to_iodata([header | sessions_csv])

      Plausible.IngestRepo.query!(["insert into events_v2 format CSVWithNames\n", events_csv])
      Plausible.IngestRepo.query!(["insert into sessions_v2 format CSVWithNames\n", sessions_csv])

      # export archive to s3
      on_ee do
        assert {:ok, _job} = Plausible.Exports.schedule_s3_export(site.id, user.email)
      else
        assert {:ok, %{args: %{"local_path" => local_path}}} =
                 Plausible.Exports.schedule_local_export(site.id, user.email)
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
            to_string(site.id),
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
            %{s3_url: s3_url} = Plausible.S3.import_presign_upload(site.id, file)
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
        CSVImporter.new_import(site, user,
          start_date: date_range.first,
          end_date: date_range.last,
          uploads: uploads,
          storage: on_ee(do: "s3", else: "local")
        )

      assert %{success: 1} = Oban.drain_queue(queue: :analytics_imports, with_safety: false)

      # validate import
      assert %SiteImport{
               start_date: ~D[2024-01-01],
               end_date: ~D[2024-01-23],
               source: :csv,
               status: :completed
             } = Repo.get_by!(SiteImport, site_id: site.id)

      assert Plausible.Stats.Clickhouse.imported_pageview_count(site) == 402
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
