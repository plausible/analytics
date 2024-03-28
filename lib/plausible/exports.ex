defmodule Plausible.Exports do
  @moduledoc """
  Contains functions to export data for events and sessions as Zip archives.
  """

  use Plausible
  import Ecto.Query

  # TODO make configurable via app env to avoid dialyzer warnings and simplify tests
  @storage if Plausible.full_build?(), do: "s3", else: "local"

  @doc """
  TODO
  """
  @spec schedule_export!(Plausible.Site.t(), Plausible.Auth.User.t(), Date.Range.t()) ::
          Oban.Job.t()
  def schedule_export!(site, user, date_range) do
    args = %{
      "storage" => @storage,
      "site_id" => site.id,
      "email_to" => user.email,
      "start_date" => date_range.first,
      "end_date" => date_range.last
    }

    # TODO or just url :: s3://bucket/path | file:://path
    extra_args =
      case @storage do
        "s3" ->
          %{
            "s3_bucket" => Plausible.S3.exports_bucket(),
            "s3_path" => s3_export_object(site.id),
            "archive_filename" => archive_filename(site.domain, date_range)
          }

        "local" ->
          %{
            "local_path" => local_export_file(site.id)
          }
      end

    Map.merge(args, extra_args)
    |> Plausible.Workers.ExportCSV.new()
    |> Oban.insert!()
  end

  @doc """
  TODO
  """
  @spec schedule_export_rate_limit(
          Plausible.Site.t(),
          Plausible.Auth.User.t(),
          Date.Range.t(),
          pos_integer
        ) ::
          {:ok, Oban.Job.t()} | {:error, :rate_limit}
  def schedule_export_rate_limit(site, user, date_range, max_jobs) do
    Plausible.Repo.transaction(fn ->
      exports_today_q =
        from j in Oban.Job,
          where: j.scheduled_at > fragment("now() - interval '24h'"),
          where: j.worker == "Plausible.Workers.ExportCSV",
          where: j.args["site_id"] == ^site.id

      exports_today = Plausible.Repo.aggregate(exports_today_q, :count)

      if exports_today < max_jobs do
        {:ok, schedule_export!(site, user, date_range)}
      else
        {:error, :rate_limit}
      end
    end)
  end

  @doc "Returns the date range for the site's events data or `nil` if there is no data"
  @spec date_range(non_neg_integer) :: Date.range() | nil
  def date_range(site_id) do
    [%Date{} = start_date, %Date{} = end_date] =
      Plausible.ClickhouseRepo.one(
        from e in "events_v2",
          where: [site_id: ^site_id],
          select: [
            fragment("toDate(min(?))", e.timestamp),
            fragment("toDate(max(?))", e.timestamp)
          ]
      )

    unless end_date == ~D[1970-01-01] do
      Date.range(start_date, end_date)
    end
  end

  @doc """
  TODO
  """
  def archive_filename(domain, %Date.Range{first: start_date, last: end_date}) do
    format_domain(domain) <>
      "-" <>
      format_date(start_date) <>
      "-" <>
      format_date(end_date) <> ".zip"
  end

  def archive_filename(domain, %Date{} = end_date) do
    format_domain(domain) <> "-" <> format_date(end_date) <> ".zip"
  end

  defp format_domain(domain), do: String.replace(domain, ".", "_")
  defp format_date(date), do: Calendar.strftime(date, "%Y%m%d")

  @doc ~S"""
  Safely renders content disposition for an arbitrary filename.

  Examples:

      iex> content_disposition("Plausible.zip")
      "attachment; filename=\"Plausible.zip\""

      iex> content_disposition("ウェブサイトのエクスポート_それから現在まで.zip")
      "attachment; filename=\"%E3%82%A6%E3%82%A7%E3%83%96%E3%82%B5%E3%82%A4%E3%83%88%E3%81%AE%E3%82%A8%E3%82%AF%E3%82%B9%E3%83%9D%E3%83%BC%E3%83%88_%E3%81%9D%E3%82%8C%E3%81%8B%E3%82%89%E7%8F%BE%E5%9C%A8%E3%81%BE%E3%81%A7.zip\"; filename*=utf-8''%E3%82%A6%E3%82%A7%E3%83%96%E3%82%B5%E3%82%A4%E3%83%88%E3%81%AE%E3%82%A8%E3%82%AF%E3%82%B9%E3%83%9D%E3%83%BC%E3%83%88_%E3%81%9D%E3%82%8C%E3%81%8B%E3%82%89%E7%8F%BE%E5%9C%A8%E3%81%BE%E3%81%A7.zip"

  """
  def content_disposition(filename) do
    encoded_filename = URI.encode(filename)
    disposition = ~s[attachment; filename="#{encoded_filename}"]

    if encoded_filename != filename do
      disposition <> "; filename*=utf-8''#{encoded_filename}"
    else
      disposition
    end
  end

  @doc false
  def s3_export_object(site_id), do: Integer.to_string(site_id)

  @doc """
  Returns local path for CSV exports storage.

  Builds upon `$PERSISTENT_CACHE_DIR` (if set) and falls back to /tmp

  Examples:

      iex> path = local_export_file(_site_id = 37)
      iex> String.ends_with?(path, "/plausible-exports/37")
      true

  """
  def local_export_file(site_id) do
    persistent_cache_dir = Application.get_env(:plausible, :persistent_cache_dir)

    Path.join([
      persistent_cache_dir || System.tmp_dir!(),
      "plausible-exports",
      Integer.to_string(site_id)
    ])
  end

  @doc """
  Builds Ecto queries to export data from `events_v2` and `sessions_v2`
  tables  into the format of `imported_*` tables for a website.
  """
  @spec export_queries(pos_integer, extname: String.t(), date_range: Date.Range.t()) ::
          %{String.t() => Ecto.Query.t()}
  def export_queries(site_id, opts \\ []) do
    extname = opts[:extname] || ".csv"
    date_range = opts[:date_range]

    filename = fn table ->
      name =
        if date_range do
          first_date = Timex.format!(date_range.first, "{YYYY}{0M}{0D}")
          last_date = Timex.format!(date_range.last, "{YYYY}{0M}{0D}")
          "#{table}_#{first_date}_#{last_date}"
        else
          table
        end

      name <> extname
    end

    %{
      filename.("imported_visitors") => export_visitors_q(site_id, date_range),
      filename.("imported_sources") => export_sources_q(site_id, date_range),
      # NOTE: this query can result in `MEMORY_LIMIT_EXCEEDED` error
      filename.("imported_pages") => export_pages_q(site_id, date_range),
      filename.("imported_entry_pages") => export_entry_pages_q(site_id, date_range),
      filename.("imported_exit_pages") => export_exit_pages_q(site_id, date_range),
      filename.("imported_locations") => export_locations_q(site_id, date_range),
      filename.("imported_devices") => export_devices_q(site_id, date_range),
      filename.("imported_browsers") => export_browsers_q(site_id, date_range),
      filename.("imported_operating_systems") => export_operating_systems_q(site_id, date_range)
    }
  end

  on_full_build do
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

  defmacrop date(timestamp) do
    quote do
      selected_as(fragment("toDate(?)", unquote(timestamp)), :date)
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

  def export_visitors_q(site_id, date_range \\ nil) do
    visitors_sessions_q =
      from s in sampled("sessions_v2", date_range),
        where: s.site_id == ^site_id,
        group_by: selected_as(:date),
        select: %{
          date: date(s.start),
          bounces: bounces(s),
          visits: visits(s),
          visit_duration: visit_duration(s)
          # NOTE: can we use just sessions_v2 table in this query? sum(pageviews) and visitors(s)?
          # visitors: visitors(s)
        }

    visitors_events_q =
      from e in sampled("events_v2", date_range),
        where: e.site_id == ^site_id,
        group_by: selected_as(:date),
        select: %{
          date: date(e.timestamp),
          visitors: visitors(e),
          pageviews:
            selected_as(
              fragment("toUInt64(round(countIf(?='pageview')*any(_sample_factor)))", e.name),
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
        e.visitors,
        e.pageviews,
        s.bounces,
        s.visits,
        s.visit_duration
      ]
  end

  def export_sources_q(site_id, date_range \\ nil) do
    from s in sampled("sessions_v2", date_range),
      where: s.site_id == ^site_id,
      group_by: [
        selected_as(:date),
        selected_as(:source),
        s.utm_medium,
        s.utm_campaign,
        s.utm_content,
        s.utm_term
      ],
      order_by: selected_as(:date),
      select: [
        date(s.start),
        selected_as(s.referrer_source, :source),
        s.utm_medium,
        s.utm_campaign,
        s.utm_content,
        s.utm_term,
        visitors(s),
        visits(s),
        visit_duration(s),
        bounces(s)
      ]
  end

  def export_pages_q(site_id, date_range \\ nil) do
    window_q =
      from e in sampled("events_v2", date_range),
        where: e.site_id == ^site_id,
        select: %{
          timestamp: e.timestamp,
          next_timestamp:
            over(fragment("leadInFrame(?)", e.timestamp),
              partition_by: e.session_id,
              order_by: e.timestamp,
              frame: fragment("ROWS BETWEEN CURRENT ROW AND 1 FOLLOWING")
            ),
          pathname: e.pathname,
          hostname: e.hostname,
          name: e.name,
          user_id: e.user_id,
          _sample_factor: fragment("_sample_factor")
        }

    from e in subquery(window_q),
      group_by: [selected_as(:date), e.pathname],
      order_by: selected_as(:date),
      select: [
        date(e.timestamp),
        selected_as(fragment("any(?)", e.hostname), :hostname),
        selected_as(e.pathname, :page),
        visitors(e),
        selected_as(
          fragment("toUInt64(round(countIf(?='pageview')*any(_sample_factor)))", e.name),
          :pageviews
        ),
        # NOTE: are exits pageviews or any events?
        selected_as(
          fragment("toUInt64(round(countIf(?=0)*any(_sample_factor)))", e.next_timestamp),
          :exits
        ),
        selected_as(
          fragment("sum(greatest(?,0))", e.next_timestamp - e.timestamp),
          :time_on_page
        )
      ]
  end

  def export_entry_pages_q(site_id, date_range \\ nil) do
    from s in sampled("sessions_v2", date_range),
      where: s.site_id == ^site_id,
      group_by: [selected_as(:date), s.entry_page],
      order_by: selected_as(:date),
      select: [
        date(s.start),
        s.entry_page,
        visitors(s),
        selected_as(
          fragment("toUInt64(round(sum(?)*any(_sample_factor)))", s.sign),
          :entrances
        ),
        visit_duration(s),
        bounces(s)
      ]
  end

  def export_exit_pages_q(site_id, date_range \\ nil) do
    from s in sampled("sessions_v2", date_range),
      where: s.site_id == ^site_id,
      group_by: [selected_as(:date), s.exit_page],
      order_by: selected_as(:date),
      select: [
        date(s.start),
        s.exit_page,
        visitors(s),
        selected_as(
          fragment("toUInt64(round(sum(?)*any(_sample_factor)))", s.sign),
          :exits
        )
      ]
  end

  def export_locations_q(site_id, date_range \\ nil) do
    from s in sampled("sessions_v2", date_range),
      where: s.site_id == ^site_id,
      where: s.city_geoname_id != 0 and s.country_code != "\0\0" and s.country_code != "ZZ",
      group_by: [selected_as(:date), s.country_code, selected_as(:region), s.city_geoname_id],
      order_by: selected_as(:date),
      select: [
        date(s.start),
        selected_as(s.country_code, :country),
        selected_as(s.subdivision1_code, :region),
        selected_as(s.city_geoname_id, :city),
        visitors(s),
        visits(s),
        visit_duration(s),
        bounces(s)
      ]
  end

  def export_devices_q(site_id, date_range \\ nil) do
    from s in sampled("sessions_v2", date_range),
      where: s.site_id == ^site_id,
      group_by: [selected_as(:date), s.screen_size],
      order_by: selected_as(:date),
      select: [
        date(s.start),
        selected_as(s.screen_size, :device),
        visitors(s),
        visits(s),
        visit_duration(s),
        bounces(s)
      ]
  end

  def export_browsers_q(site_id, date_range \\ nil) do
    from s in sampled("sessions_v2", date_range),
      where: s.site_id == ^site_id,
      group_by: [selected_as(:date), s.browser],
      order_by: selected_as(:date),
      select: [
        date(s.start),
        s.browser,
        visitors(s),
        visits(s),
        visit_duration(s),
        bounces(s)
      ]
  end

  def export_operating_systems_q(site_id, date_range \\ nil) do
    from s in sampled("sessions_v2", date_range),
      where: s.site_id == ^site_id,
      group_by: [selected_as(:date), s.operating_system],
      order_by: selected_as(:date),
      select: [
        date(s.start),
        s.operating_system,
        visitors(s),
        visits(s),
        visit_duration(s),
        bounces(s)
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
