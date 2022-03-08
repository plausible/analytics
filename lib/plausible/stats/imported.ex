defmodule Plausible.Stats.Imported do
  use Plausible.ClickhouseRepo
  alias Plausible.Stats.Query
  import Ecto.Query

  @no_ref "Direct / None"

  def merge_imported_timeseries(native_q, _, %Plausible.Stats.Query{include_imported: false}, _),
    do: native_q

  def merge_imported_timeseries(
        native_q,
        site,
        query,
        metrics
      ) do
    imported_q =
      from(v in "imported_visitors",
        where: v.site_id == ^site.id,
        where: v.date >= ^query.date_range.first and v.date <= ^query.date_range.last,
        select: %{visitors: sum(v.visitors)}
      )
      |> apply_interval(query)

    from(s in Ecto.Query.subquery(native_q),
      full_join: i in subquery(imported_q),
      on: field(s, :date) == field(i, :date)
    )
    |> select_joined_metrics(metrics)
  end

  defp apply_interval(imported_q, %Plausible.Stats.Query{interval: "month"}) do
    imported_q
    |> group_by([i], fragment("toStartOfMonth(?)", i.date))
    |> select_merge([i], %{date: fragment("toStartOfMonth(?)", i.date)})
  end

  defp apply_interval(imported_q, _query) do
    imported_q
    |> group_by([i], i.date)
    |> select_merge([i], %{date: i.date})
  end

  def merge_imported(q, _, %Query{include_imported: false}, _, _), do: q
  def merge_imported(q, _, _, _, [:events | _]), do: q
  # GA only has 'source'
  def merge_imported(q, _, _, "utm_source", _), do: q

  def merge_imported(q, site, query, property, metrics)
      when property in [
             "visit:source",
             "visit:utm_medium",
             "visit:utm_campaign",
             "visit:utm_term",
             "visit:utm_content",
             "visit:entry_page",
             "visit:exit_page",
             "visit:country",
             "visit:region",
             "visit:city",
             "visit:device",
             "visit:browser",
             "visit:os",
             "event:page"
           ] do
    {table, dim} =
      case property do
        "visit:country" ->
          {"imported_locations", :country}

        "visit:region" ->
          {"imported_locations", :region}

        "visit:city" ->
          {"imported_locations", :city}

        "visit:utm_medium" ->
          {"imported_sources", :utm_medium}

        "visit:utm_campaign" ->
          {"imported_sources", :utm_campaign}

        "visit:utm_term" ->
          {"imported_sources", :utm_term}

        "visit:utm_content" ->
          {"imported_sources", :utm_content}

        "visit:os" ->
          {"imported_operating_systems", :operating_system}

        "event:page" ->
          {"imported_pages", :page}

        _ ->
          dim = String.trim_leading(property, "visit:")
          {"imported_#{dim}s", String.to_existing_atom(dim)}
      end

    imported_q =
      from(
        i in table,
        group_by: field(i, ^dim),
        where: i.site_id == ^site.id,
        where: i.date >= ^query.date_range.first and i.date <= ^query.date_range.last,
        select: %{}
      )
      |> select_imported_metrics(metrics)

    imported_q =
      case query.filters[property] do
        {:is_not, value} ->
          value = if value == @no_ref, do: "", else: value
          where(imported_q, [i], field(i, ^dim) != ^value)

        {:member, list} ->
          where(imported_q, [i], field(i, ^dim) in ^list)

        _ ->
          imported_q
      end

    imported_q =
      case dim do
        :source ->
          imported_q
          |> select_merge([i], %{
            source: fragment("if(empty(?), ?, ?)", i.source, @no_ref, i.source)
          })

        :utm_medium ->
          imported_q
          |> select_merge([i], %{
            utm_medium: fragment("if(empty(?), ?, ?)", i.utm_medium, @no_ref, i.utm_medium)
          })

        :utm_source ->
          imported_q
          |> select_merge([i], %{
            utm_source: fragment("if(empty(?), ?, ?)", i.utm_source, @no_ref, i.utm_source)
          })

        :utm_campaign ->
          imported_q
          |> select_merge([i], %{
            utm_campaign: fragment("if(empty(?), ?, ?)", i.utm_campaign, @no_ref, i.utm_campaign)
          })

        :utm_term ->
          imported_q
          |> select_merge([i], %{
            utm_term: fragment("if(empty(?), ?, ?)", i.utm_term, @no_ref, i.utm_term)
          })

        :utm_content ->
          imported_q
          |> select_merge([i], %{
            utm_content: fragment("if(empty(?), ?, ?)", i.utm_content, @no_ref, i.utm_content)
          })

        :page ->
          imported_q
          |> select_merge([i], %{
            page: i.page,
            time_on_page: sum(i.time_on_page)
          })

        :entry_page ->
          imported_q
          |> select_merge([i], %{
            entry_page: i.entry_page,
            visits: sum(i.entrances)
          })

        :exit_page ->
          imported_q
          |> select_merge([i], %{exit_page: i.exit_page, visits: sum(i.exits)})

        :country ->
          imported_q |> select_merge([i], %{country: i.country})

        :region ->
          imported_q |> select_merge([i], %{region: i.region})

        :city ->
          imported_q |> select_merge([i], %{city: i.city})

        :device ->
          imported_q |> select_merge([i], %{device: i.device})

        :browser ->
          imported_q |> select_merge([i], %{browser: i.browser})

        :operating_system ->
          imported_q |> select_merge([i], %{operating_system: i.operating_system})
      end

    q =
      from(s in Ecto.Query.subquery(q),
        full_join: i in subquery(imported_q),
        on: field(s, ^dim) == field(i, ^dim)
      )
      |> select_joined_metrics(metrics)
      |> apply_order_by(metrics)

    case dim do
      :source ->
        q
        |> select_merge([s, i], %{
          source: fragment("if(empty(?), ?, ?)", s.source, i.source, s.source)
        })

      :utm_medium ->
        q
        |> select_merge([s, i], %{
          utm_medium: fragment("if(empty(?), ?, ?)", s.utm_medium, i.utm_medium, s.utm_medium)
        })

      :utm_source ->
        q
        |> select_merge([s, i], %{
          utm_source: fragment("if(empty(?), ?, ?)", s.utm_source, i.utm_source, s.utm_source)
        })

      :utm_campaign ->
        q
        |> select_merge([s, i], %{
          utm_campaign:
            fragment("if(empty(?), ?, ?)", s.utm_campaign, i.utm_campaign, s.utm_campaign)
        })

      :utm_term ->
        q
        |> select_merge([s, i], %{
          utm_term: fragment("if(empty(?), ?, ?)", s.utm_term, i.utm_term, s.utm_term)
        })

      :utm_content ->
        q
        |> select_merge([s, i], %{
          utm_content: fragment("if(empty(?), ?, ?)", s.utm_content, i.utm_content, s.utm_content)
        })

      :page ->
        q
        |> select_merge([s, i], %{
          page: fragment("if(empty(?), ?, ?)", i.page, s.page, i.page)
        })

      :entry_page ->
        q
        |> select_merge([s, i], %{
          entry_page: fragment("if(empty(?), ?, ?)", i.entry_page, s.entry_page, i.entry_page),
          visits: fragment("? + ?", s.visits, i.visits)
        })

      :exit_page ->
        q
        |> select_merge([s, i], %{
          exit_page: fragment("if(empty(?), ?, ?)", i.exit_page, s.exit_page, i.exit_page),
          visits: fragment("coalesce(?, 0) + coalesce(?, 0)", s.visits, i.visits)
        })

      :country ->
        q
        |> select_merge([i, s], %{
          country: fragment("if(empty(?), ?, ?)", s.country, i.country, s.country)
        })

      :region ->
        q
        |> select_merge([i, s], %{
          region: fragment("if(empty(?), ?, ?)", s.region, i.region, s.region)
        })

      :city ->
        q
        |> select_merge([i, s], %{
          city: fragment("coalesce(?, ?)", s.city, i.city)
        })

      :device ->
        q
        |> select_merge([i, s], %{
          device: fragment("if(empty(?), ?, ?)", s.device, i.device, s.device)
        })

      :browser ->
        q
        |> select_merge([i, s], %{
          browser: fragment("if(empty(?), ?, ?)", s.browser, i.browser, s.browser)
        })

      :operating_system ->
        q
        |> select_merge([i, s], %{
          operating_system:
            fragment(
              "if(empty(?), ?, ?)",
              s.operating_system,
              i.operating_system,
              s.operating_system
            )
        })
    end
  end

  def merge_imported(q, site, query, :aggregate, metrics) do
    imported_q =
      from(
        i in "imported_visitors",
        where: i.site_id == ^site.id,
        where: i.date >= ^query.date_range.first and i.date <= ^query.date_range.last,
        select: %{}
      )
      |> select_imported_metrics(metrics)

    from(
      s in subquery(q),
      cross_join: i in subquery(imported_q),
      select: %{}
    )
    |> select_joined_metrics(metrics)
  end

  def merge_imported(q, _, _, _, _), do: q

  defp select_imported_metrics(q, []), do: q

  defp select_imported_metrics(q, [:visitors | rest]) do
    q
    |> select_merge([i], %{visitors: sum(i.visitors)})
    |> select_imported_metrics(rest)
  end

  defp select_imported_metrics(q, [:pageviews | rest]) do
    q
    |> select_merge([i], %{pageviews: sum(i.pageviews)})
    |> select_imported_metrics(rest)
  end

  defp select_imported_metrics(q, [:bounce_rate | rest]) do
    q
    |> select_merge([i], %{
      bounces: sum(i.bounces),
      visits: sum(i.visits)
    })
    |> select_imported_metrics(rest)
  end

  defp select_imported_metrics(q, [:visit_duration | rest]) do
    q
    |> select_merge([i], %{visit_duration: sum(i.visit_duration)})
    |> select_imported_metrics(rest)
  end

  defp select_imported_metrics(q, [_ | rest]) do
    q
    |> select_imported_metrics(rest)
  end

  defp select_joined_metrics(q, []), do: q
  # TODO: Reverse-engineering the native data bounces and total visit
  # durations to combine with imported data is inefficient. Instead both
  # queries should fetch bounces/total_visit_duration and visits and be
  # used as subqueries to a main query that then find the bounce rate/avg
  # visit_duration.

  defp select_joined_metrics(q, [:visitors | rest]) do
    q
    |> select_merge([s, i], %{
      :visitors => fragment("coalesce(?, 0) + coalesce(?, 0)", s.visitors, i.visitors)
    })
    |> select_joined_metrics(rest)
  end

  defp select_joined_metrics(q, [:pageviews | rest]) do
    q
    |> select_merge([s, i], %{
      pageviews: fragment("coalesce(?, 0) + coalesce(?, 0)", s.pageviews, i.pageviews)
    })
    |> select_joined_metrics(rest)
  end

  defp select_joined_metrics(q, [:bounce_rate | rest]) do
    q
    |> select_merge([s, i], %{
      bounce_rate:
        fragment(
          "round(100 * (coalesce(?, 0) + coalesce((? * ? / 100), 0)) / (coalesce(?, 0) + coalesce(?, 0)))",
          i.bounces,
          s.bounce_rate,
          s.visits,
          i.visits,
          s.visits
        )
    })
    |> select_joined_metrics(rest)
  end

  defp select_joined_metrics(q, [:visit_duration | rest]) do
    q
    |> select_merge([s, i], %{
      visit_duration:
        fragment(
          "(? + ? * ?) / (? + ?)",
          i.visit_duration,
          s.visit_duration,
          s.visits,
          s.visits,
          i.visits
        )
    })
    |> select_joined_metrics(rest)
  end

  defp select_joined_metrics(q, [:sample_percent | rest]) do
    q
    |> select_merge([s, i], %{sample_percent: s.sample_percent})
    |> select_joined_metrics(rest)
  end

  defp select_joined_metrics(q, [_ | rest]) do
    q
    |> select_joined_metrics(rest)
  end

  defp apply_order_by(q, [:visitors | rest]) do
    order_by(q, [s, i], desc: fragment("coalesce(?, 0) + coalesce(?, 0)", s.visitors, i.visitors))
    |> apply_order_by(rest)
  end

  defp apply_order_by(q, _), do: q
end
