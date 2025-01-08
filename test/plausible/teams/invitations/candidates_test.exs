defmodule Plausible.Teams.Invitations.CandidatesTest do
  use Plausible.DataCase, async: true
  use Plausible.Teams.Test

  alias Plausible.Teams.Invitations.Candidates

  test "performs basic searches" do
    owner = new_user()
    site = new_site(owner: owner)

    add_guest(site, role: :viewer, user: new_user(email: "foo@example.com", name: "Jane Doe"))
    add_guest(site, role: :viewer, user: new_user(email: "foo2@example.com", name: "Joe Doe"))
    add_guest(site, role: :viewer, user: new_user(email: "moo@example.com", name: "Wu Tang"))

    assert [
             %{email: "foo@example.com"},
             %{email: "foo2@example.com"}
           ] = Candidates.search_site_guests(team_of(owner), "doe")

    assert [
             %{email: "foo@example.com"},
             %{email: "foo2@example.com"}
           ] = Candidates.search_site_guests(team_of(owner), "FOO")

    assert [
             %{email: "foo@example.com"},
             %{email: "foo2@example.com"},
             %{email: "moo@example.com"}
           ] = Candidates.search_site_guests(team_of(owner), "")

    assert [] = Candidates.search_site_guests(team_of(owner), "WONTMATCH")
  end

  test "searches across multiple sites" do
    owner = new_user()

    site1 = new_site(owner: owner)
    site2 = new_site(owner: owner)

    multi_site_guest = new_user(email: "foo@example.com", name: "Jane Doe")

    add_guest(site1, role: :viewer, user: multi_site_guest)
    add_guest(site2, role: :viewer, user: new_user(email: "foo2@example.com", name: "Joe Doe"))
    add_guest(site2, role: :viewer, user: multi_site_guest)

    assert [
             %{email: "foo@example.com"},
             %{email: "foo2@example.com"}
           ] = Candidates.search_site_guests(team_of(owner), "doe")
  end

  test "capable of limiting results" do
    owner = new_user()
    site = new_site(owner: owner)

    add_guest(site, role: :viewer)
    add_guest(site, role: :viewer)
    add_guest(site, role: :viewer)

    assert [_, _, _] = Candidates.search_site_guests(team_of(owner), "")
    assert [_, _] = Candidates.search_site_guests(team_of(owner), "", limit: 2)
  end
end
