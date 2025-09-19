defmodule Plausible.Workers.SendEmailReport do
  use Plausible.Repo
  use Oban.Worker, queue: :send_email_reports, max_attempts: 1

  alias Plausible.Stats.{Query, QueryResult}

  @weekly "weekly"
  @monthly "monthly"

  def perform(%Oban.Job{args: %{"interval" => interval, "site_id" => site_id}})
      when interval in [@weekly, @monthly] do
    report_type = report_type(interval)

    site =
      Plausible.Site
      |> Repo.get(site_id)
      |> Repo.preload(report_type)

    report = site && Map.get(site, report_type)

    if report do
      date_range = date_range(site, interval)
      report_name = report_name(interval, date_range.first)
      date_label = Calendar.strftime(date_range.last, "%-d %b %Y")
      stats = stats(site, date_range)

      report
      |> Map.fetch!(:recipients)
      |> Enum.each(fn email ->
        assigns = %{
          site: site,
          report_name: report_name,
          date_label: date_label,
          unsubscribe_link: unsubscribe_link(site, email, interval),
          site_member?: site_member?(site, email),
          interval: interval,
          stats: stats
        }

        email
        |> PlausibleWeb.Email.stats_report(assigns)
        |> Plausible.Mailer.send()
      end)
    else
      :discard
    end
  end

  defp report_type(@weekly), do: :weekly_report
  defp report_type(@monthly), do: :monthly_report

  defp site_member?(site, email) do
    user = Plausible.Auth.find_user_by(email: email)
    user && Plausible.Teams.Memberships.site_member?(site, user)
  end

  defp unsubscribe_link(site, email, interval) do
    PlausibleWeb.Endpoint.url() <>
      "/sites/#{URI.encode_www_form(site.domain)}/#{interval}-report/unsubscribe?email=#{email}"
  end

  defp report_name(@weekly, _), do: "Weekly"
  defp report_name(@monthly, first), do: Calendar.strftime(first, "%B")

  defp stats(site, date_range) do
    date_range = [
      Date.to_iso8601(date_range.first),
      Date.to_iso8601(date_range.last)
    ]

    stats = stats_aggreagates(site, date_range)
    pages = pages(site, date_range)
    sources = sources(site, date_range)
    goals = goals(site, date_range)

    stats
    |> Map.put(:pages, pages)
    |> Map.put(:sources, sources)
    |> Map.put(:goals, goals)
  end

  defp stats_aggreagates(site, date_range) do
    {:ok, query} =
      Query.build(
        site,
        :internal,
        %{
          # site_id parameter is required, but it doesn't matter what we pass here since the query is executed against a specific site later on
          "site_id" => site.domain,
          "metrics" => ["pageviews", "visitors", "bounce_rate"],
          "date_range" => date_range,
          "include" => %{"comparisons" => %{"mode" => "previous_period"}},
          "pagination" => %{"limit" => 5}
        },
        %{}
      )

    %QueryResult{
      results: [
        %{
          metrics: [pageviews, visitors, bounce_rate],
          comparison: %{
            change: [pageviews_change, visitors_change, bounce_rate_change]
          }
        }
      ]
    } = Plausible.Stats.query(site, query)

    %{
      pageviews: %{value: pageviews, change: pageviews_change},
      visitors: %{value: visitors, change: visitors_change},
      bounce_rate: %{value: bounce_rate, change: bounce_rate_change}
    }
  end

  defp pages(site, date_range) do
    {:ok, query} =
      Query.build(
        site,
        :internal,
        %{
          # site_id parameter is required, but it doesn't matter what we pass here since the query is executed against a specific site later on
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "dimensions" => ["event:page"],
          "date_range" => date_range,
          "pagination" => %{"limit" => 5}
        },
        %{}
      )

    site
    |> Plausible.Stats.query(query)
    |> Map.fetch!(:results)
    |> Enum.map(fn %{metrics: [visitors], dimensions: [page]} ->
      %{
        page: page,
        visitors: visitors
      }
    end)
  end

  defp sources(site, date_range) do
    {:ok, query} =
      Query.build(
        site,
        :internal,
        %{
          # site_id parameter is required, but it doesn't matter what we pass here since the query is executed against a specific site later on
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "filters" => [["is_not", "visit:source", ["Direct / None"]]],
          "dimensions" => ["visit:source"],
          "date_range" => date_range,
          "pagination" => %{"limit" => 5}
        },
        %{}
      )

    site
    |> Plausible.Stats.query(query)
    |> Map.fetch!(:results)
    |> Enum.map(fn %{metrics: [visitors], dimensions: [source]} ->
      %{
        source: source,
        visitors: visitors
      }
    end)
  end

  defp goals(site, date_range) do
    {:ok, query} =
      Query.build(
        site,
        :internal,
        %{
          # site_id parameter is required, but it doesn't matter what we pass here since the query is executed against a specific site later on
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "dimensions" => ["event:goal"],
          "date_range" => date_range,
          "pagination" => %{"limit" => 5}
        },
        %{}
      )

    site
    |> Plausible.Stats.query(query)
    |> Map.fetch!(:results)
    |> Enum.map(fn %{metrics: [visitors], dimensions: [goal_name]} ->
      %{
        goal: goal_name,
        visitors: visitors
      }
    end)
  end

  defp date_range(site, @weekly) do
    first =
      site.timezone
      |> DateTime.now!()
      |> Date.shift(day: -7)
      |> Date.beginning_of_week()

    last =
      site.timezone
      |> DateTime.now!()
      |> DateTime.to_date()
      |> Date.shift(day: -7)
      |> Date.end_of_week()

    Date.range(first, last)
  end

  defp date_range(site, @monthly) do
    first =
      site.timezone
      |> DateTime.now!()
      |> Date.shift(month: -1)
      |> Date.beginning_of_month()

    last =
      site.timezone
      |> DateTime.now!()
      |> DateTime.shift(month: -1)
      |> DateTime.to_date()
      |> Date.end_of_month()

    Date.range(first, last)
  end
end
