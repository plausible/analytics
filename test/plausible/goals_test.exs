defmodule Plausible.GoalsTest do
  use Plausible.DataCase

  alias Plausible.Goals

  test "create/2 trims input" do
    site = insert(:site)
    {:ok, goal} = Goals.create(site, %{"page_path" => "/foo bar "})
    assert goal.page_path == "/foo bar"

    {:ok, goal} = Goals.create(site, %{"event_name" => "  some event name   "})
    assert goal.event_name == "some event name"
  end

  test "for_domain/2 returns trimmed input even if it was saved with trailing whitespace" do
    site = insert(:site)
    insert(:goal, %{domain: site.domain, event_name: " Signup "})
    insert(:goal, %{domain: site.domain, page_path: " /Signup "})

    goals = Goals.for_domain(site.domain)

    assert [%{event_name: "Signup"}, %{page_path: "/Signup"}] = goals
  end
end
