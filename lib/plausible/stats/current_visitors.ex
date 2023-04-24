defmodule Plausible.Stats.CurrentVisitors do
  use Plausible.ClickhouseRepo
  use Plausible.Stats.Fragments

  def current_visitors(site) do
    first_datetime =
      NaiveDateTime.utc_now()
      |> Timex.shift(minutes: -5)
      |> NaiveDateTime.truncate(:second)

    ClickhouseRepo.one(
      from e in "events_v2",
        where: e.site_id == ^site.id,
        where: e.timestamp >= ^first_datetime,
        select: uniq(e.user_id)
    )
  end
end
