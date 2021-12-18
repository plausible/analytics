defmodule Plausible.Event.Props do
  use Plausible.Repo
  use Plausible.ClickhouseRepo

  def props(site) do
    Repo.all(from g in Plausible.Goal, where: g.domain == ^site.domain)
    |> Enum.map(fn evt ->
      %{
        id: evt.id,
        name: if(evt.event_name, do: evt.event_name, else: "Visit #{evt.page_path}"),
        event_type: if(evt.event_name, do: "custom", else: "pageview"),
        props: properties_for_event(site, evt.event_name)
      }
    end)
  end

  def props(site, event_name) do
    properties_for_event(site, event_name)
  end

  def properties_for_event(site, event_name) do
    q =
      from(
        e in "events",
        inner_lateral_join: meta in fragment("meta as m"),
        select: meta.key,
        distinct: true,
        where: e.domain == ^site.domain
      )

    q =
      case event_name do
        nil ->
          from(e in q, where: is_nil(e.name))

        _ ->
          from(e in q, where: e.name == ^event_name)
      end

    Enum.map(ClickhouseRepo.all(q), fn x -> x end)
  end
end
