defmodule Plausible.ClickhouseRepoTest do
  use Plausible.DataCase
  import Plausible.TestUtils
  import Ecto.Query

  setup [:create_user, :create_new_site]

  test "clear_events_for/2 deletes events by name and domain", %{site: %{domain: domain} = site} do
    event_to_delete = "clean_events_for_to_delete"

    populate_stats(site, [
      build(:event, name: event_to_delete),
      build(:event, name: event_to_delete),
      build(:event, name: "clear_events_for_other"),
      build(:pageview, pathname: "/"),
      build(:pageview, pathname: "/"),
      build(:pageview, pathname: "/register"),
      build(:pageview, pathname: "/register"),
      build(:pageview, pathname: "/contact")
    ])

    assert :ok == Plausible.ClickhouseRepo.clear_events_for(domain, event_to_delete)

    assert eventually(fn ->
             from(e in Plausible.ClickhouseEvent,
               where: e.domain == ^domain and e.name == ^event_to_delete
             )
             |> Plausible.ClickhouseRepo.aggregate(:count)
             |> Kernel.==(0)
           end),
           "expected events to be deleted"
  end

  test "clear_events_for/2 deletes only past events", %{site: %{domain: domain} = site} do
    event_to_delete = "clean_events_for_to_delete"

    future =
      DateTime.utc_now()
      |> DateTime.add(3600, :second)
      |> DateTime.to_naive()
      |> NaiveDateTime.truncate(:second)

    populate_stats(site, [
      build(:event, name: event_to_delete),
      build(:event, name: event_to_delete),
      build(:event, name: event_to_delete, timestamp: future)
    ])

    assert :ok == Plausible.ClickhouseRepo.clear_events_for(domain, event_to_delete)

    assert eventually(fn ->
             from(e in Plausible.ClickhouseEvent,
               where: e.domain == ^domain and e.name == ^event_to_delete
             )
             |> Plausible.ClickhouseRepo.aggregate(:count)
             |> Kernel.==(1)
           end),
           "expected past events to be deleted"
  end
end
