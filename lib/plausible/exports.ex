defmodule Plausible.Exports do
  @moduledoc """
  Contains functions to export data for events and sessions as Zip archives.
  """

  # NOTE: needs tests

  import Ecto.Query

  @doc """
  Builds Ecto queries to export data from `events_v2` and `sessions_v2`
  tables  into the format of `imported_*` tables for a website.
  """
  @spec export_queries(pos_integer, extname: String.t()) :: %{String.t() => Ecto.Query.t()}
  def export_queries(site_id, opts \\ []) do
    extname = opts[:extname] || ".csv"

    %{
      "imported_visitors#{extname}" => export_visitors_q(site_id),
      "imported_sources#{extname}" => export_sources_q(site_id),
      # NOTE: this query can result in `MEMORY_LIMIT_EXCEEDED` error
      "imported_pages#{extname}" => export_pages_q(site_id),
      "imported_entry_pages#{extname}" => export_entry_pages_q(site_id),
      "imported_exit_pages#{extname}" => export_exit_pages_q(site_id),
      "imported_locations#{extname}" => export_locations_q(site_id),
      "imported_devices#{extname}" => export_devices_q(site_id),
      "imported_browsers#{extname}" => export_browsers_q(site_id),
      "imported_operating_systems#{extname}" => export_operating_systems_q(site_id)
    }
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
      from s in "sessions_v2",
        # NOTE: no smapling is used right now
        # hints: ["SAMPLE", unsafe_fragment(^@sample)],
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
      from e in "events_v2",
        # NOTE: no smapling is used right now
        # hints: ["SAMPLE", unsafe_fragment(^@sample)],
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
    from s in "sessions_v2",
      # NOTE: no smapling is used right now
      # hints: ["SAMPLE", unsafe_fragment(^@sample)],
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
      from e in "events_v2",
        # NOTE: no smapling is used right now
        # hints: ["SAMPLE", unsafe_fragment(^@sample)],
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
    from s in "sessions_v2",
      # NOTE: no smapling is used right now
      # hints: ["SAMPLE", unsafe_fragment(^@sample)],
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
    from s in "sessions_v2",
      # NOTE: no smapling is used right now
      # hints: ["SAMPLE", unsafe_fragment(^@sample)],
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
    from s in "sessions_v2",
      # NOTE: no smapling is used right now
      # hints: ["SAMPLE", unsafe_fragment(^@sample)],
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
    from s in "sessions_v2",
      # NOTE: no smapling is used right now
      # hints: ["SAMPLE", unsafe_fragment(^@sample)],
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
    from s in "sessions_v2",
      # NOTE: no smapling is used right now
      # hints: ["SAMPLE", unsafe_fragment(^@sample)],
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
    from s in "sessions_v2",
      # NOTE: no smapling is used right now
      # hints: ["SAMPLE", unsafe_fragment(^@sample)],
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
