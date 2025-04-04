defmodule Plausible.Exports do
  @moduledoc """
  Contains functions to export data for events and sessions as Zip archives.
  """

  use Plausible
  use Plausible.Stats.SQL.Fragments
  import Ecto.Query

  @doc "Schedules CSV export job to S3 storage"
  @spec schedule_s3_export(pos_integer, pos_integer | nil, String.t()) ::
          {:ok, Oban.Job.t()} | {:error, :no_data}
  def schedule_s3_export(site_id, current_user_id, email_to) do
    with :ok <- ensure_has_data(site_id) do
      args = %{
        "storage" => "s3",
        "site_id" => site_id,
        "email_to" => email_to,
        "current_user_id" => current_user_id,
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

      %{path: path, name: name, expires_at: nil, size: size}
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
    data_dir = Application.get_env(:plausible, :data_dir)
    Path.join([data_dir || System.tmp_dir!(), "plausible-exports", Integer.to_string(site_id)])
  end

  @doc "Gets S3 export for a site. Raises if object storage is unavailable."
  @spec get_s3_export!(pos_integer, non_neg_integer) :: export | nil
  def get_s3_export!(site_id, retries \\ 0) do
    path = s3_export_key(site_id)
    bucket = Plausible.S3.exports_bucket()
    head_object_op = ExAws.S3.head_object(bucket, path)

    case ExAws.request(head_object_op, retries: retries) do
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
          size: String.to_integer(size)
        }

      {:error, {:http_error, 404, _response}} ->
        nil

      {:error, %Mint.TransportError{} = e} ->
        raise e
    end
  end

  @doc "Deletes S3 export for a site. Raises if object storage is unavailable."
  @spec delete_s3_export!(pos_integer) :: :ok
  def delete_s3_export!(site_id) do
    if export = get_s3_export!(site_id) do
      exports_bucket = Plausible.S3.exports_bucket()
      delete_op = ExAws.S3.delete_object(exports_bucket, export.path)
      ExAws.request!(delete_op)
    end

    :ok
  end

  defp s3_export_key(site_id), do: Integer.to_string(site_id)

  @doc "Returns the date range for the site's events data in site's timezone or `nil` if there is no data"
  @spec date_range(pos_integer, String.t()) :: Date.Range.t() | nil
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
        first_date = Calendar.strftime(date_range.first, "%Y%m%d")
        last_date = Calendar.strftime(date_range.last, "%Y%m%d")
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
      filename.("imported_custom_events") =>
        export_custom_events_q(site_id, timezone, date_range),
      filename.("imported_locations") => export_locations_q(site_id, timezone, date_range),
      filename.("imported_devices") => export_devices_q(site_id, timezone, date_range),
      filename.("imported_browsers") => export_browsers_q(site_id, timezone, date_range),
      filename.("imported_operating_systems") =>
        export_operating_systems_q(site_id, timezone, date_range)
    }
  end

  on_ee do
    defp sampled(table) do
      Plausible.Stats.Sampling.add_query_hint(from(table))
    end
  else
    defp sampled(table) do
      table
    end
  end

  defp export_filter(site_id, date_range) do
    filter = dynamic([t], t.site_id == ^site_id)

    if date_range do
      dynamic(
        ^filter and
          selected_as(:date) >= ^date_range.first and
          selected_as(:date) <= ^date_range.last
      )
    else
      filter
    end
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
        scale_sample(fragment("greatest(sum(?*?),0)", unquote(t).sign, unquote(t).duration)),
        :visit_duration
      )
    end
  end

  defmacrop visitors(t) do
    quote do
      selected_as(
        scale_sample(fragment("uniq(?)", unquote(t).user_id)),
        :visitors
      )
    end
  end

  defmacrop visits(t) do
    quote do
      selected_as(
        scale_sample(fragment("greatest(sum(?),0)", unquote(t).sign)),
        :visits
      )
    end
  end

  defmacrop bounces(t) do
    quote do
      selected_as(
        scale_sample(
          fragment(
            "greatest(sum(?*?),0)",
            unquote(t).sign,
            unquote(t).is_bounce
          )
        ),
        :bounces
      )
    end
  end

  defmacrop pageviews(t) do
    quote do
      selected_as(
        scale_sample(
          fragment(
            "greatest(sum(?*?),0)",
            unquote(t).sign,
            unquote(t).pageviews
          )
        ),
        :pageviews
      )
    end
  end

  defp export_visitors_q(site_id, timezone, date_range) do
    visitors_sessions_q =
      from s in sampled("sessions_v2"),
        where: ^export_filter(site_id, date_range),
        group_by: selected_as(:date),
        select: %{
          date: date(s.timestamp, ^timezone),
          bounces: bounces(s),
          visits: visits(s),
          visit_duration: visit_duration(s),
          visitors: visitors(s)
        }

    visitors_events_q =
      from e in sampled("events_v2"),
        where: ^export_filter(site_id, date_range),
        group_by: selected_as(:date),
        select: %{
          date: date(e.timestamp, ^timezone),
          pageviews:
            selected_as(
              scale_sample(fragment("countIf(?='pageview')", e.name)),
              :pageviews
            )
        }

    visitors_q =
      "e"
      |> with_cte("e", as: ^visitors_events_q)
      |> with_cte("s", as: ^visitors_sessions_q)

    from e in visitors_q,
      full_join: s in "s",
      on: e.date == s.date,
      order_by: selected_as(:date),
      select: [
        selected_as(fragment("greatest(?,?)", s.date, e.date), :date),
        s.visitors,
        e.pageviews,
        s.bounces,
        s.visits,
        s.visit_duration
      ]
  end

  defp export_sources_q(site_id, timezone, date_range) do
    from s in sampled("sessions_v2"),
      where: ^export_filter(site_id, date_range),
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
      select: [
        date(s.timestamp, ^timezone),
        selected_as(s.referrer_source, :source),
        s.referrer,
        s.utm_source,
        s.utm_medium,
        s.utm_campaign,
        s.utm_content,
        s.utm_term,
        pageviews(s),
        visitors(s),
        visits(s),
        visit_duration(s),
        bounces(s)
      ]
  end

  defp export_pages_q(site_id, timezone, date_range) do
    base_q =
      from(e in sampled("events_v2"),
        where: ^export_filter(site_id, date_range),
        where: [name: "pageview"],
        group_by: [selected_as(:date), selected_as(:page)],
        order_by: selected_as(:date)
      )

    max_scroll_depth_per_session_q =
      from(e in "events_v2",
        where: ^export_filter(site_id, date_range),
        where: e.name == "engagement" and e.scroll_depth <= 100,
        select: %{
          date: date(e.timestamp, ^timezone),
          page: selected_as(e.pathname, :page),
          session_id: e.session_id,
          max_scroll_depth: max(e.scroll_depth)
        },
        group_by: [e.session_id, selected_as(:date), selected_as(:page)]
      )

    scroll_depth_q =
      from(p in subquery(max_scroll_depth_per_session_q),
        select: %{
          date: p.date,
          page: p.page,
          total_scroll_depth: fragment("sum(?)", p.max_scroll_depth),
          total_scroll_depth_visits: fragment("uniq(?)", p.session_id)
        },
        group_by: [:date, :page]
      )

    from(e in base_q,
      left_join: s in subquery(scroll_depth_q),
      on: s.date == selected_as(:date) and s.page == selected_as(:page),
      select: %{
        date: date(e.timestamp, ^timezone),
        hostname: selected_as(fragment("any(?)", e.hostname), :hostname),
        page: selected_as(e.pathname, :page),
        visits:
          selected_as(
            scale_sample(fragment("uniq(?)", e.session_id)),
            :visits
          ),
        visitors: visitors(e),
        pageviews: selected_as(scale_sample(fragment("count()")), :pageviews),
        total_scroll_depth:
          selected_as(fragment("any(?)", s.total_scroll_depth), :total_scroll_depth),
        total_scroll_depth_visits:
          selected_as(fragment("any(?)", s.total_scroll_depth_visits), :total_scroll_depth_visits)
      }
    )
    |> add_time_on_page_columns(site_id, timezone, date_range)
  end

  defp add_time_on_page_columns(q, site_id, timezone, date_range) do
    site = Plausible.Repo.get(Plausible.Site, site_id)

    if Plausible.Stats.TimeOnPage.new_time_on_page_visible?(site) do
      cutoff = Plausible.Stats.TimeOnPage.legacy_time_on_page_cutoff(site)

      engagements_q =
        from(e in sampled("events_v2"),
          where: ^export_filter(site_id, date_range),
          where: e.name == "engagement",
          group_by: [selected_as(:date), selected_as(:page)],
          order_by: selected_as(:date),
          select: %{
            date: date(e.timestamp, ^timezone),
            page: selected_as(e.pathname, :page),
            total_time_on_page:
              fragment(
                "toUInt64(round(sumIf(?, ? >= ?) / 1000))",
                e.engagement_time,
                e.timestamp,
                ^cutoff
              ),
            total_time_on_page_visits:
              fragment("uniqIf(?, ? >= ?)", e.session_id, e.timestamp, ^cutoff)
          }
        )

      q
      |> join(:left, [], s in subquery(engagements_q),
        on: s.date == selected_as(:date) and s.page == selected_as(:page)
      )
      |> select_merge_as([..., s], %{
        total_time_on_page: fragment("any(?)", s.total_time_on_page),
        total_time_on_page_visits: fragment("any(?)", s.total_time_on_page_visits)
      })
    else
      q
    end
  end

  defp export_entry_pages_q(site_id, timezone, date_range) do
    from s in sampled("sessions_v2"),
      where: ^export_filter(site_id, date_range),
      group_by: [selected_as(:date), s.entry_page],
      order_by: selected_as(:date),
      select: [
        date(s.timestamp, ^timezone),
        s.entry_page,
        visitors(s),
        selected_as(
          scale_sample(fragment("greatest(sum(?),0)", s.sign)),
          :entrances
        ),
        visit_duration(s),
        bounces(s),
        pageviews(s)
      ]
  end

  defp export_exit_pages_q(site_id, timezone, date_range) do
    from s in sampled("sessions_v2"),
      where: ^export_filter(site_id, date_range),
      group_by: [selected_as(:date), s.exit_page],
      order_by: selected_as(:date),
      select: [
        date(s.timestamp, ^timezone),
        s.exit_page,
        visitors(s),
        visit_duration(s),
        selected_as(
          scale_sample(fragment("greatest(sum(?),0)", s.sign)),
          :exits
        ),
        bounces(s),
        pageviews(s)
      ]
  end

  defp export_custom_events_q(site_id, timezone, date_range) do
    from e in sampled("events_v2"),
      where: ^export_filter(site_id, date_range),
      where: e.name != "pageview",
      group_by: [
        selected_as(:date),
        e.name,
        selected_as(:link_url),
        selected_as(:path)
      ],
      order_by: selected_as(:date),
      select: [
        date(e.timestamp, ^timezone),
        e.name,
        selected_as(
          fragment(
            "if(? in ?, ?, '')",
            e.name,
            ^Plausible.Imported.goals_with_url(),
            get_by_key(e, :meta, "url")
          ),
          :link_url
        ),
        selected_as(
          fragment(
            "if(? in ?, ?, '')",
            e.name,
            ^Plausible.Imported.goals_with_path(),
            get_by_key(e, :meta, "path")
          ),
          :path
        ),
        visitors(e),
        selected_as(scale_sample(fragment("count()")), :events)
      ]
  end

  defp export_locations_q(site_id, timezone, date_range) do
    from s in sampled("sessions_v2"),
      where: ^export_filter(site_id, date_range),
      where: s.country_code != "\0\0" and s.country_code != "ZZ",
      group_by: [selected_as(:date), s.country_code, s.subdivision1_code, s.city_geoname_id],
      order_by: selected_as(:date),
      select: [
        date(s.timestamp, ^timezone),
        selected_as(s.country_code, :country),
        selected_as(s.subdivision1_code, :region),
        selected_as(s.city_geoname_id, :city),
        visitors(s),
        visits(s),
        visit_duration(s),
        bounces(s),
        pageviews(s)
      ]
  end

  defp export_devices_q(site_id, timezone, date_range) do
    from s in sampled("sessions_v2"),
      where: ^export_filter(site_id, date_range),
      group_by: [selected_as(:date), s.screen_size],
      order_by: selected_as(:date),
      select: [
        date(s.timestamp, ^timezone),
        selected_as(s.screen_size, :device),
        visitors(s),
        visits(s),
        visit_duration(s),
        bounces(s),
        pageviews(s)
      ]
  end

  defp export_browsers_q(site_id, timezone, date_range) do
    from s in sampled("sessions_v2"),
      where: ^export_filter(site_id, date_range),
      group_by: [selected_as(:date), s.browser, s.browser_version],
      order_by: selected_as(:date),
      select: [
        date(s.timestamp, ^timezone),
        s.browser,
        s.browser_version,
        visitors(s),
        visits(s),
        visit_duration(s),
        bounces(s),
        pageviews(s)
      ]
  end

  defp export_operating_systems_q(site_id, timezone, date_range) do
    from s in sampled("sessions_v2"),
      where: ^export_filter(site_id, date_range),
      group_by: [selected_as(:date), s.operating_system, s.operating_system_version],
      order_by: selected_as(:date),
      select: [
        date(s.timestamp, ^timezone),
        s.operating_system,
        s.operating_system_version,
        visitors(s),
        visits(s),
        visit_duration(s),
        bounces(s),
        pageviews(s)
      ]
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
