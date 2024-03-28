defmodule Plausible.Exports do
  @moduledoc """
  Contains functions to export data for events and sessions as Zip archives.
  """

  require Plausible
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

    archive_filename = archive_filename(site.domain, date_range.first, date_range.last)

    # TODO or just url :: s3://bucket/path | file:://path
    extra_args =
      case @storage do
        "s3" ->
          %{
            "s3_bucket" => Plausible.S3.exports_bucket(),
            "s3_path" => "/#{site.id}/#{archive_filename}"
          }

        "local" ->
          %{
            "local_path" => Path.join(local_dir(site.id), archive_filename)
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
  Renders filename for the Zip archive containing the exported CSV files.

  Examples:

      iex> archive_filename("plausible.io", ~D[2021-01-01], ~D[2024-12-31])
      "plausible_io_20210101_20241231.zip"

      iex> archive_filename("Bücher.example", ~D[2021-01-01], ~D[2024-12-31])
      "Bücher_example_20210101_20241231.zip"

  """
  def archive_filename(domain, min_date, max_date) do
    name =
      Enum.join(
        [
          String.replace(domain, ".", "_"),
          Calendar.strftime(min_date, "%Y%m%d"),
          Calendar.strftime(max_date, "%Y%m%d")
        ],
        "_"
      )

    name <> ".zip"
  end

  @doc ~S"""
  Safely renders content disposition for an arbitrary filename.

  Examples:

      iex> content_disposition("Plausible.zip")
      "attachment; filename=\"Plausible.zip\""

      iex> content_disposition(archive_filename("plausible.io", ~D[2021-01-01], ~D[2024-12-31]))
      "attachment; filename=\"plausible_io_20210101_20241231.zip\""

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

  @doc ~S"""
  Returns local directory for CSV exports storage.

  Builds upon `$PERSISTENT_CACHE_DIR` (if set) and falls back to /tmp

  Examples:

      iex> local_dir = local_dir(_site_id = 37)
      iex> String.ends_with?(local_dir, "/plausible-exports/37")
      true

  """
  def local_dir(site_id) do
    persistent_cache_dir = Application.get_env(:plausible, :persistent_cache_dir)

    Path.join([
      persistent_cache_dir || System.tmp_dir!(),
      "plausible-exports",
      i(site_id)
    ])
  end

  @doc """
  Generates a random path for the export. The random part is nested in `local_dir/1`.

  Example:

      random_file(_site_id = 37)
      /tmp/plausible-exports/37/1711500789-932639561109-1

  """
  def random_file(site_id) do
    sec = :os.system_time(:second)
    rand = :rand.uniform(999_999_999_999)
    scheduler_id = :erlang.system_info(:scheduler_id)
    Path.join(local_dir(site_id), i(sec) <> "-" <> i(rand) <> "-" <> i(scheduler_id))
  end

  @compile {:inline, i: 1}
  defp i(integer), do: Integer.to_string(integer)

  defmodule LocalExport do
    @moduledoc false
    defstruct [:state, :path, :job_id, :size, :last_error]

    @type t :: %__MODULE__{
            state: String.t(),
            path: Path.t(),
            job_id: non_neg_integer() | nil,
            size: non_neg_integer() | nil,
            last_error: String.t() | nil
          }
  end

  @doc "Lists both in progress and completed exports"
  @spec list_local_exports(pos_integer) :: [LocalExport.t()]
  def list_local_exports(site_id) do
    import Ecto.Query, only: [from: 2]

    local_dir = local_dir(site_id)

    completed =
      if File.exists?(local_dir) do
        local_dir
        |> File.ls!()
        |> Enum.map(fn file ->
          path = Path.join(local_dir, file)
          %LocalExport{state: "completed", path: path, size: File.stat!(path).size}
        end)
      else
        []
      end

    completed_paths = MapSet.new(completed, & &1.path)

    jobs_q =
      from j in Oban.Job,
        where: [worker: "Plausible.Workers.ExportCSVLocal"],
        where: j.args["site_id"] == ^site_id,
        where: j.state not in ["completed", "cancelled"],
        order_by: [asc: :id]

    in_progress =
      jobs_q
      |> Plausible.Repo.all()
      |> Enum.map(fn job ->
        %Oban.Job{
          id: job_id,
          state: state,
          errors: errors,
          args: %{"local_path" => path}
        } = job

        last_error =
          if last_error = List.last(errors) do
            Map.fetch!(last_error, "error")
          end

        %LocalExport{state: state, path: path, job_id: job_id, last_error: last_error}
      end)
      |> Enum.reject(&MapSet.member?(completed_paths, &1.path))

    Enum.sort_by(completed ++ in_progress, & &1.path)
  end

  @oban_channel __MODULE__
  @doc false
  def oban_notify(site_id) do
    Oban.Notifier.notify(Oban, @oban_channel, %{"site_id" => site_id})
  end

  # TODO subscribe only for site id
  @doc "Subscribes for export job updates"
  def oban_listen, do: Oban.Notifier.listen([@oban_channel])

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

    # TODO limit export queries to the provided date range (if provided)

    %{
      filename.("imported_visitors") => export_visitors_q(site_id),
      filename.("imported_sources") => export_sources_q(site_id),
      # NOTE: this query can result in `MEMORY_LIMIT_EXCEEDED` error
      filename.("imported_pages") => export_pages_q(site_id),
      filename.("imported_entry_pages") => export_entry_pages_q(site_id),
      filename.("imported_exit_pages") => export_exit_pages_q(site_id),
      filename.("imported_locations") => export_locations_q(site_id),
      filename.("imported_devices") => export_devices_q(site_id),
      filename.("imported_browsers") => export_browsers_q(site_id),
      filename.("imported_operating_systems") => export_operating_systems_q(site_id)
    }
  end

  Plausible.on_full_build do
    defp sampled(table) do
      Plausible.Stats.Sampling.add_query_hint(from(table))
    end
  else
    defp sampled(table) do
      table
    end
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

  @spec export_visitors_q(pos_integer) :: Ecto.Query.t()
  def export_visitors_q(site_id) do
    visitors_sessions_q =
      from s in sampled("sessions_v2"),
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
      from e in sampled("events_v2"),
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

  @spec export_sources_q(pos_integer) :: Ecto.Query.t()
  def export_sources_q(site_id) do
    from s in sampled("sessions_v2"),
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

  @spec export_pages_q(pos_integer) :: Ecto.Query.t()
  def export_pages_q(site_id) do
    window_q =
      from e in sampled("events_v2"),
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

  @spec export_entry_pages_q(pos_integer) :: Ecto.Query.t()
  def export_entry_pages_q(site_id) do
    from s in sampled("sessions_v2"),
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

  @spec export_exit_pages_q(pos_integer) :: Ecto.Query.t()
  def export_exit_pages_q(site_id) do
    from s in sampled("sessions_v2"),
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

  @spec export_locations_q(pos_integer) :: Ecto.Query.t()
  def export_locations_q(site_id) do
    from s in sampled("sessions_v2"),
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

  @spec export_devices_q(pos_integer) :: Ecto.Query.t()
  def export_devices_q(site_id) do
    from s in sampled("sessions_v2"),
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

  @spec export_browsers_q(pos_integer) :: Ecto.Query.t()
  def export_browsers_q(site_id) do
    from s in sampled("sessions_v2"),
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

  @spec export_operating_systems_q(pos_integer) :: Ecto.Query.t()
  def export_operating_systems_q(site_id) do
    from s in sampled("sessions_v2"),
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
