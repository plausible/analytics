defmodule Plausible.Stats.CurrentVisitors do
  use Plausible.ClickhouseRepo
  use Plausible.Stats.SQL.Fragments

  @spec current_visitors(Plausible.Site.t(), Duration.duration()) :: non_neg_integer
  def current_visitors(site, duration \\ Duration.new!(minute: -5)) do
    first_datetime =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.shift(duration)
      |> NaiveDateTime.truncate(:second)

    ClickhouseRepo.one(
      from e in "events_v2",
        where: e.site_id == ^site.id,
        where: e.timestamp >= ^first_datetime,
        select: uniq(e.user_id)
    )
  end
end
