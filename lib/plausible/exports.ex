defmodule Plausible.Exports do
  @moduledoc """
  Contains functions to export data for events and sessions as Zip archives.
  """

  use Plausible
  import Ecto.Query

  @doc "Schedules CSV export job to S3 storage"
  @spec schedule_s3_export(pos_integer, String.t()) :: {:ok, Oban.Job.t()} | {:error, :no_data}
  def schedule_s3_export(site_id, email_to) do
    with :ok <- ensure_has_data(site_id) do
      args = %{
        "storage" => "s3",
        "site_id" => site_id,
        "email_to" => email_to,
        "s3_bucket" => Plausible.S3.exports_bucket(),
        "s3_path" => s3_export_key(site_id)
      }

      {:ok, Oban.insert!(Plausible.Workers.ExportAnalytics.new(args))}
    end
  end

  @doc "Schedules CSV export job to local storage"
  @spec schedule_local_export(pos_integer, String.t()) :: {:ok, Oban.Job.t()} | {:error, :no_data}
  def schedule_local_export(site_id, email_to) do
    with :ok <- ensure_has_data(site_id) do
      args = %{
        "storage" => "local",
        "site_id" => site_id,
        "email_to" => email_to,
        "local_path" => local_export_file(site_id)
      }

      {:ok, Oban.insert!(Plausible.Workers.ExportAnalytics.new(args))}
    end
  end

  @spec ensure_has_data(pos_integer) :: :ok | {:error, :no_data}
  defp ensure_has_data(site_id) do
    # SELECT true FROM "events_v2" AS e0 WHERE (e0."site_id" = ^site_id) LIMIT 1
    has_data? = Plausible.ClickhouseRepo.exists?(from "events_v2", where: [site_id: ^site_id])
    if has_data?, do: :ok, else: {:error, :no_data}
  end

  @doc "Gets last CSV export job for a site"
  @spec get_last_export_job(pos_integer) :: Oban.Job.t() | nil
  def get_last_export_job(site_id) do
    Plausible.Repo.one(
      from e in Plausible.Workers.ExportAnalytics.base_query(site_id),
        order_by: [desc: :id],
        limit: 1
    )
  end

  @doc "Subscribes to CSV export job notifications"
  def oban_listen, do: Oban.Notifier.listen(__MODULE__)
  @doc false
  def oban_notify(site_id), do: Oban.Notifier.notify(__MODULE__, %{"site_id" => site_id})

  @doc """
  Renders export archive filename.

  Examples:

      iex> archive_filename("plausible.io", _created_on = ~D[2024-12-31])
      "plausible_io_20241231.zip"

  """
  def archive_filename(domain, %Date{} = created_on) do
    String.replace(domain, ".", "_") <> "_" <> Calendar.strftime(created_on, "%Y%m%d") <> ".zip"
  end

  @doc ~S"""
  Safely renders content disposition for an arbitrary export filename.

  Examples:

      iex> content_disposition("plausible_io_20241231.zip")
      "attachment; filename=\"plausible_io_20241231.zip\""

      iex> content_disposition("📊.zip")
      "attachment; filename=\"plausible-export.zip\"; filename*=utf-8''%F0%9F%93%8A.zip"

  """
  def content_disposition(filename) do
    encoded_filename = URI.encode(filename)

    if encoded_filename == filename do
      ~s[attachment; filename="#{filename}"]
    else
      ~s[attachment; filename="plausible-export.zip"; filename*=utf-8''#{encoded_filename}]
    end
  end

  @type export :: %{
          path: Path.t(),
          name: String.t(),
          expires_at: DateTime.t() | nil,
          download_link: String.t(),
          size: pos_integer
        }

  @doc "Gets local export for a site"
  @spec get_local_export(pos_integer, String.t(), String.t()) :: export | nil
  def get_local_export(site_id, domain, timezone) do
    path = local_export_file(site_id)

    if File.exists?(path) do
      %File.Stat{size: size, mtime: mtime} = File.stat!(path, time: :posix)
      created_at = DateTime.from_unix!(mtime)
      created_on_in_site_tz = Plausible.Timezones.to_date_in_timezone(created_at, timezone)
      name = archive_filename(domain, created_on_in_site_tz)

      download_link =
        PlausibleWeb.Router.Helpers.site_path(
          PlausibleWeb.Endpoint,
          :download_local_export,
          domain
        )

      %{path: path, name: name, expires_at: nil, download_link: download_link, size: size}
    end
  end

  @doc "Deletes local export for a site"
  @spec delete_local_export(pos_integer) :: :ok
  def delete_local_export(site_id) do
    file = local_export_file(site_id)

    if File.exists?(file) do
      File.rm!(file)
    end

    :ok
  end

  @spec local_export_file(pos_integer) :: Path.t()
  defp local_export_file(site_id) do
    persistent_cache_dir = Application.get_env(:plausible, :persistent_cache_dir)

    Path.join([
      persistent_cache_dir || System.tmp_dir!(),
      "plausible-exports",
      Integer.to_string(site_id)
    ])
  end

  @doc "Gets S3 export for a site"
  @spec get_s3_export(pos_integer) :: export | nil
  def get_s3_export(site_id) do
    path = s3_export_key(site_id)
    bucket = Plausible.S3.exports_bucket()
    head_object_op = ExAws.S3.head_object(bucket, path)

    case ExAws.request(head_object_op) do
      {:error, {:http_error, 404, _response}} ->
        nil

      {:ok, %{status_code: 200, headers: headers}} ->
        "attachment; filename=" <> filename = :proplists.get_value("content-disposition", headers)
        name = String.trim(filename, "\"")
        size = :proplists.get_value("content-length", headers, nil)

        expires_at =
          if x_amz_expiration = :proplists.get_value("x-amz-expiration", headers, nil) do
            ["expiry-date=", expiry_date, ", rule-id=", _rule_id] =
              String.split(x_amz_expiration, "\"", trim: true)

            Timex.parse!(expiry_date, "{RFC1123}")
          end

        %{
          path: path,
          name: name,
          expires_at: expires_at,
          download_link: Plausible.S3.download_url(bucket, path),
          size: String.to_integer(size)
        }
    end
  end

  @doc "Deletes S3 export for a site"
  @spec delete_s3_export(pos_integer) :: :ok
  def delete_s3_export(site_id) do
    if export = get_s3_export(site_id) do
      exports_bucket = Plausible.S3.exports_bucket()
      delete_op = ExAws.S3.delete_object(exports_bucket, export.path)
      ExAws.request!(delete_op)
    end

    :ok
  end

  defp s3_export_key(site_id), do: Integer.to_string(site_id)

  @doc "Returns the date range for the site's events data in site's timezone or `nil` if there is no data"
  @spec date_range(non_neg_integer, String.t()) :: Date.Range.t() | nil
  def date_range(site_id, timezone) do
    [%Date{} = start_date, %Date{} = end_date] =
      Plausible.ClickhouseRepo.one(
        from e in "events_v2",
          where: [site_id: ^site_id],
          select: [
            fragment("toDate(min(?),?)", e.timestamp, ^timezone),
            fragment("toDate(max(?),?)", e.timestamp, ^timezone)
          ]
      )

    unless end_date == ~D[1970-01-01] do
      Date.range(start_date, end_date)
    end
  end

  @doc """
  Builds Ecto queries to export data from `events_v2` and `sessions_v2`
  tables into the format of `imported_*` tables for a website.
  """
  @spec export_queries(pos_integer,
          extname: String.t(),
          date_range: Date.Range.t(),
          timezone: String.t()
        ) ::
          %{String.t() => Ecto.Query.t()}
  def export_queries(site_id, opts \\ []) do
    extname = opts[:extname] || ".csv"
    date_range = opts[:date_range]
    timezone = opts[:timezone] || "UTC"

    suffix =
      if date_range do
        first_date = Timex.format!(date_range.first, "{YYYY}{0M}{0D}")
        last_date = Timex.format!(date_range.last, "{YYYY}{0M}{0D}")
        "_#{first_date}_#{last_date}" <> extname
      else
        extname
      end

    filename = fn name -> name <> suffix end

    %{
      filename.("imported_visitors") => export_visitors_q(site_id, timezone, date_range),
      filename.("imported_sources") => export_sources_q(site_id, timezone, date_range),
      filename.("imported_pages") => export_pages_q(site_id, timezone, date_range),
      filename.("imported_entry_pages") => export_entry_pages_q(site_id, timezone, date_range),
      filename.("imported_exit_pages") => export_exit_pages_q(site_id, timezone, date_range),
      filename.("imported_locations") => export_locations_q(site_id, timezone, date_range),
      filename.("imported_devices") => export_devices_q(site_id, timezone, date_range),
      filename.("imported_browsers") => export_browsers_q(site_id, timezone, date_range),
      filename.("imported_operating_systems") =>
        export_operating_systems_q(site_id, timezone, date_range)
    }
  end

  on_ee do
    defp sampled(table, date_range) do
      from(table)
      |> Plausible.Stats.Sampling.add_query_hint()
      |> limit_date_range(date_range)
    end
  else
    defp sampled(table, date_range) do
      limit_date_range(table, date_range)
    end
  end

  defp limit_date_range(query, nil), do: query

  defp limit_date_range(query, date_range) do
    from t in query,
      where:
        selected_as(:date) >= ^date_range.first and
          selected_as(:date) <= ^date_range.last
  end

  defmacrop date(timestamp, timezone) do
    quote do
      selected_as(
        fragment("toDate(?,?)", unquote(timestamp), unquote(timezone)),
        :date
      )
    end
  end

  defmacrop visit_duration(t) do
    quote do
      selected_as(
        fragment("greatest(sum(?*?),0)", unquote(t).sign, unquote(t).duration),
        :visit_duration
      )
    end
  end

  defmacrop visitors(t) do
    quote do
      selected_as(
        fragment("toUInt64(round(uniq(?)*any(_sample_factor)))", unquote(t).user_id),
        :visitors
      )
    end
  end

  defmacrop visits(t) do
    quote do
      selected_as(sum(unquote(t).sign), :visits)
    end
  end

  defmacrop bounces(t) do
    quote do
      selected_as(
        fragment("greatest(sum(?*?),0)", unquote(t).sign, unquote(t).is_bounce),
        :bounces
      )
    end
  end

  defp pageviews_q(site_id, timezone, date_range) do
    from e in sampled("events_v2", date_range),
      where: [site_id: ^site_id, name: "pageview"],
      select: %{
        date: date(e.timestamp, ^timezone),
        pageviews: fragment("toUInt64(round(count()*any(_sample_factor)))")
      }
  end

  defp export_visitors_q(site_id, timezone, date_range) do
    visitors_q =
      from s in sampled("sessions_v2", date_range),
        where: [site_id: ^site_id],
        group_by: selected_as(:date),
        select: %{
          date: date(s.start, ^timezone),
          visitors: visitors(s),
          bounces: bounces(s),
          visits: visits(s),
          visit_duration: visit_duration(s)
        }

    pageviews_q =
      from p in pageviews_q(site_id, timezone, date_range),
        group_by: selected_as(:date)

    "visitors"
    |> with_cte("visitors", as: ^visitors_q)
    |> with_cte("pageviews", as: ^pageviews_q)
    |> join(:full, [v], p in "pageviews", on: v.date == p.date)
    |> order_by([], selected_as(:date))
    |> select([v, p], [
      selected_as(fragment("greatest(?,?)", v.date, p.date), :date),
      v.visitors,
      p.pageviews,
      v.bounces,
      v.visits,
      v.visit_duration
    ])
  end

  defp export_sources_q(site_id, timezone, date_range) do
    sources_q =
      from s in sampled("sessions_v2", date_range),
        where: s.site_id == ^site_id,
        group_by: [
          selected_as(:date),
          selected_as(:source),
          s.referrer,
          s.utm_source,
          s.utm_medium,
          s.utm_campaign,
          s.utm_content,
          s.utm_term
        ],
        order_by: selected_as(:date),
        select: %{
          date: date(s.start, ^timezone),
          source: selected_as(s.referrer_source, :source),
          referrer: s.referrer,
          utm_source: s.utm_source,
          utm_medium: s.utm_medium,
          utm_campaign: s.utm_campaign,
          utm_content: s.utm_content,
          utm_term: s.utm_term,
          visitors: visitors(s),
          visits: visits(s),
          visit_duration: visit_duration(s),
          bounces: bounces(s)
        }

    pageviews_q =
      from p in pageviews_q(site_id, timezone, date_range),
        select_merge: %{
          source: selected_as(p.referrer_source, :source),
          referrer: p.referrer,
          utm_source: p.utm_source,
          utm_medium: p.utm_medium,
          utm_campaign: p.utm_campaign,
          utm_content: p.utm_content,
          utm_term: p.utm_term
        },
        group_by: [
          selected_as(:date),
          selected_as(:source),
          p.referrer,
          p.utm_source,
          p.utm_medium,
          p.utm_campaign,
          p.utm_content,
          p.utm_term
        ]

    "sources"
    |> with_cte("sources", as: ^sources_q)
    |> with_cte("pageviews", as: ^pageviews_q)
    |> join(:left, [s], p in "pageviews",
      on:
        s.date == p.date and
          s.source == p.source and
          s.referrer == p.referrer and
          s.utm_source == p.utm_source and
          s.utm_medium == p.utm_medium and
          s.utm_campaign == p.utm_campaign and
          s.utm_content == p.utm_content and
          s.utm_term == p.utm_term
    )
    |> order_by([s], s.date)
    |> select([s, p], [
      s.date,
      s.source,
      s.referrer,
      s.utm_source,
      s.utm_medium,
      s.utm_campaign,
      s.utm_content,
      s.utm_term,
      p.pageviews,
      s.visitors,
      s.visits,
      s.visit_duration,
      s.bounces
    ])
  end

  defp export_pages_q(site_id, timezone, date_range) do
    from e in sampled("events_v2", date_range),
      where: [site_id: ^site_id, name: "pageview"],
      group_by: [selected_as(:date), e.pathname],
      order_by: selected_as(:date),
      select: [
        date(e.timestamp, ^timezone),
        selected_as(fragment("any(?)", e.hostname), :hostname),
        selected_as(e.pathname, :page),
        selected_as(
          fragment("toUInt64(round(uniq(?)*any(_sample_factor)))", e.session_id),
          :visits
        ),
        visitors(e),
        selected_as(fragment("toUInt64(round(count()*any(_sample_factor)))"), :pageviews)
      ]
  end

  defp export_entry_pages_q(site_id, timezone, date_range) do
    entry_pages_q =
      from s in sampled("sessions_v2", date_range),
        where: s.site_id == ^site_id,
        group_by: [selected_as(:date), s.entry_page],
        order_by: selected_as(:date),
        select: %{
          date: date(s.start, ^timezone),
          entry_page: s.entry_page,
          visitors: visitors(s),
          entrances:
            selected_as(
              fragment("toUInt64(round(sum(?)*any(_sample_factor)))", s.sign),
              :entrances
            ),
          visit_duration: visit_duration(s),
          bounces: bounces(s)
        }

    pageviews_q =
      from p in pageviews_q(site_id, timezone, date_range),
        select_merge: %{pathname: p.pathname},
        group_by: [selected_as(:date), p.pathname]

    "entry_pages"
    |> with_cte("entry_pages", as: ^entry_pages_q)
    |> with_cte("pageviews", as: ^pageviews_q)
    |> join(:left, [ep], p in "pageviews", on: ep.date == p.date and ep.entry_page == p.pathname)
    |> order_by([ep], ep.date)
    |> select([ep, p], [
      ep.date,
      ep.entry_page,
      ep.visitors,
      ep.entrances,
      ep.visit_duration,
      ep.bounces,
      p.pageviews
    ])
  end

  defp export_exit_pages_q(site_id, timezone, date_range) do
    exit_pages_q =
      from s in sampled("sessions_v2", date_range),
        where: s.site_id == ^site_id,
        group_by: [selected_as(:date), s.exit_page],
        order_by: selected_as(:date),
        select: %{
          date: date(s.start, ^timezone),
          exit_page: s.exit_page,
          visitors: visitors(s),
          visit_duration: visit_duration(s),
          exits:
            selected_as(
              fragment("toUInt64(round(sum(?)*any(_sample_factor)))", s.sign),
              :exits
            ),
          bounces: bounces(s)
        }

    pageviews_q =
      from p in pageviews_q(site_id, timezone, date_range),
        select_merge: %{pathname: p.pathname},
        group_by: [selected_as(:date), p.pathname]

    "exit_pages"
    |> with_cte("exit_pages", as: ^exit_pages_q)
    |> with_cte("pageviews", as: ^pageviews_q)
    |> join(:left, [ep], p in "pageviews", on: ep.date == p.date and ep.exit_page == p.pathname)
    |> order_by([ep], ep.date)
    |> select([ep, p], [
      ep.date,
      ep.exit_page,
      ep.visitors,
      ep.visit_duration,
      ep.exits,
      ep.bounces,
      p.pageviews
    ])
  end

  defp export_locations_q(site_id, timezone, date_range) do
    locations_q =
      from s in sampled("sessions_v2", date_range),
        where: s.site_id == ^site_id,
        where: s.city_geoname_id != 0 and s.country_code != "\0\0" and s.country_code != "ZZ",
        group_by: [
          selected_as(:date),
          selected_as(:country),
          selected_as(:region),
          selected_as(:city)
        ],
        order_by: selected_as(:date),
        select: %{
          date: date(s.start, ^timezone),
          country: selected_as(s.country_code, :country),
          region: selected_as(s.subdivision1_code, :region),
          city: selected_as(s.city_geoname_id, :city),
          visitors: visitors(s),
          visits: visits(s),
          visit_duration: visit_duration(s),
          bounces: bounces(s)
        }

    pageviews_q =
      from p in pageviews_q(site_id, timezone, date_range),
        select_merge: %{
          country: selected_as(p.country_code, :country),
          region: selected_as(p.subdivision1_code, :region),
          city_geoname_id: selected_as(p.city_geoname_id, :city)
        },
        group_by: [
          selected_as(:date),
          selected_as(:country),
          selected_as(:region),
          selected_as(:city)
        ]

    "locations"
    |> with_cte("locations", as: ^locations_q)
    |> with_cte("pageviews", as: ^pageviews_q)
    |> join(:left, [l], p in "pageviews",
      on:
        l.date == p.date and
          l.country == p.country and
          l.region == p.region and
          l.city == p.city
    )
    |> order_by([l], l.date)
    |> select([l, p], [
      l.date,
      l.country,
      l.region,
      l.city,
      l.visitors,
      l.visits,
      l.visit_duration,
      l.bounces,
      p.pageviews
    ])
  end

  defp export_devices_q(site_id, timezone, date_range) do
    devices_q =
      from s in sampled("sessions_v2", date_range),
        where: s.site_id == ^site_id,
        group_by: [selected_as(:date), selected_as(:device)],
        order_by: selected_as(:date),
        select: %{
          date: date(s.start, ^timezone),
          device: selected_as(s.screen_size, :device),
          visitors: visitors(s),
          visits: visits(s),
          visit_duration: visit_duration(s),
          bounces: bounces(s)
        }

    pageviews_q =
      from p in pageviews_q(site_id, timezone, date_range),
        select_merge: %{device: selected_as(p.screen_size, :device)},
        group_by: [selected_as(:date), selected_as(:device)]

    "devices"
    |> with_cte("devices", as: ^devices_q)
    |> with_cte("pageviews", as: ^pageviews_q)
    |> join(:left, [d], p in "pageviews", on: d.date == p.date and d.device == p.device)
    |> order_by([d], d.date)
    |> select([d, p], [
      d.date,
      d.device,
      d.visitors,
      d.visits,
      d.visit_duration,
      d.bounces,
      p.pageviews
    ])
  end

  defp export_browsers_q(site_id, timezone, date_range) do
    browsers_q =
      from s in sampled("sessions_v2", date_range),
        where: s.site_id == ^site_id,
        group_by: [selected_as(:date), s.browser, s.browser_version],
        order_by: selected_as(:date),
        select: %{
          date: date(s.start, ^timezone),
          browser: s.browser,
          browser_version: s.browser_version,
          visitors: visitors(s),
          visits: visits(s),
          visit_duration: visit_duration(s),
          bounces: bounces(s)
        }

    pageviews_q =
      from p in pageviews_q(site_id, timezone, date_range),
        select_merge: %{browser: p.browser, browser_version: p.browser_version},
        group_by: [selected_as(:date), p.browser, p.browser_version]

    "browsers"
    |> with_cte("browsers", as: ^browsers_q)
    |> with_cte("pageviews", as: ^pageviews_q)
    |> join(:left, [b], p in "pageviews",
      on: b.date == p.date and b.browser == p.browser and b.browser_version == p.browser_version
    )
    |> order_by([b], b.date)
    |> select([b, p], [
      b.date,
      b.browser,
      b.browser_version,
      b.visitors,
      b.visits,
      b.visit_duration,
      b.bounces,
      p.pageviews
    ])
  end

  defp export_operating_systems_q(site_id, timezone, date_range) do
    operation_systems_q =
      from s in sampled("sessions_v2", date_range),
        where: s.site_id == ^site_id,
        group_by: [selected_as(:date), s.operating_system, s.operating_system_version],
        order_by: selected_as(:date),
        select: %{
          date: date(s.start, ^timezone),
          operating_system: s.operating_system,
          operating_system_version: s.operating_system_version,
          visitors: visitors(s),
          visits: visits(s),
          visit_duration: visit_duration(s),
          bounces: bounces(s)
        }

    pageviews_q =
      from p in pageviews_q(site_id, timezone, date_range),
        select_merge: %{
          operating_system: p.operating_system,
          operating_system_version: p.operating_system_version
        },
        group_by: [
          selected_as(:date),
          p.operating_system,
          p.operating_system_version
        ]

    "operation_systems"
    |> with_cte("operation_systems", as: ^operation_systems_q)
    |> with_cte("pageviews", as: ^pageviews_q)
    |> join(:left, [os], p in "pageviews",
      on:
        os.date == p.date and
          os.operating_system == p.operating_system and
          os.operating_system_version == p.operating_system_version
    )
    |> order_by([os], os.date)
    |> select([os, p], [
      os.date,
      os.operating_system,
      os.operating_system_version,
      os.visitors,
      os.visits,
      os.visit_duration,
      os.bounces,
      p.pageviews
    ])
  end

  @doc """
  Creates a streamable Zip archive from the provided (named) Ecto queries.

  Example usage:

      {:ok, pool} = Ch.start_link(pool_size: 1)

      DBConnection.run(pool, fn conn ->
        conn
        |> stream_archive(export_queries(_site_id = 1), format: "CSVWithNames")
        |> Stream.into(File.stream!("export.zip"))
        |> Stream.run()
      end)

  """
  @spec stream_archive(DBConnection.t(), %{String.t() => Ecto.Query.t()}, [Ch.query_option()]) ::
          Enumerable.t()
  def stream_archive(conn, named_queries, opts \\ []) do
    entries =
      Enum.map(named_queries, fn {name, query} ->
        {sql, params} = Plausible.ClickhouseRepo.to_sql(:all, query)

        datastream =
          conn
          |> Ch.stream(sql, params, opts)
          |> Stream.map(fn %Ch.Result{data: data} -> data end)

        Zstream.entry(name, datastream, coder: Zstream.Coder.Stored)
      end)

    Zstream.zip(entries)
  end
end
