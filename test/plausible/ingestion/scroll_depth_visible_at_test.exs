defmodule Plausible.Ingestion.ScrollDepthVisibleAtTest do
  use Plausible.DataCase
  use Plausible.Teams.Test

  test "mark_scroll_depth_visible" do
    site = new_site()
    Plausible.Ingestion.ScrollDepthVisibleAt.mark_scroll_depth_visible(site.id)

    Plausible.TestUtils.eventually(fn ->
      site = Plausible.Repo.reload!(site)
      {not is_nil(site.scroll_depth_visible_at), site.scroll_depth_visible_at}
    end)
  end
end
