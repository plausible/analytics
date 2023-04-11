defmodule Plausible.Site.SiteRemovalTest do
  use Plausible.DataCase, async: true
  use Oban.Testing, repo: Plausible.Repo

  alias Plausible.Site.Removal
  alias Plausible.Sites

  test "site from postgres is immediately deleted" do
    site = insert(:site)
    assert {:ok, context} = Removal.run(site.domain)
    assert context.delete_all == {1, nil}
    refute Sites.get_by_domain(site.domain)
  end

  test "deletion is idempotent" do
    assert {:ok, context} = Removal.run("some.example.com")
    assert context.delete_all == {0, nil}
  end
end
