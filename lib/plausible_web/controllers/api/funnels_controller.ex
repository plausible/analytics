defmodule PlausibleWeb.Api.FunnelsController do
  use PlausibleWeb, :controller

  alias Plausible.Funnels

  @snippet """
    import Plausible.Factory
  Plausible.Repo.delete_all(Plausible.Goal)
  Plausible.Repo.delete_all(Plausible.Funnel)
  site = Plausible.Sites.get_by_domain("dummy.site")

  g1 = insert(:goal, site: site, page_path: "/product/car")
  g2 = insert(:goal, site: site, event_name: "Add to cart")
  g3 = insert(:goal, site: site, page_path: "/view/checkout")
  g4 = insert(:goal, site: site, event_name: "Purchase")

  Plausible.Funnels.create(site, "Successful purchase", [g1, g2, g3, g4])

  to_be_populated = [g1, g2, g3, g4] |> Enum.map(fn goal ->
    if goal.page_path do
      build(:pageview, pathname: goal.page_path, user_id: 123)
    else
      build(:event, name: goal.event_name, user_id: 123)
    end
  end)

  Plausible.TestUtils.populate_stats(site, to_be_populated)

  to_be_populated = [g1, g2, g3] |> Enum.map(fn goal ->
    if goal.page_path do
      build(:pageview, pathname: goal.page_path, user_id: 666)
    else
      build(:event, name: goal.event_name, user_id: 666)
    end
  end)

  Plausible.TestUtils.populate_stats(site, to_be_populated)

  to_be_populated = [g1, g2] |> Enum.map(fn goal ->
    if goal.page_path do
      build(:pageview, pathname: goal.page_path, user_id: 222)
    else
      build(:event, name: goal.event_name, user_id: 222)
    end
  end)

  Plausible.TestUtils.populate_stats(site, to_be_populated)

  to_be_populated = [g1] |> Enum.map(fn goal ->
    if goal.page_path do
      build(:pageview, pathname: goal.page_path, user_id: 999)
    else
      build(:event, name: goal.event_name, user_id: 999)
    end
  end)

  Plausible.TestUtils.populate_stats(site, to_be_populated)
  """

  def show(conn, %{"id" => funnel_id}) do
    site_id = conn.assigns.site.id
    {funnel_id, ""} = Integer.parse(funnel_id)
    funnel = Funnels.evaluate(:nop, funnel_id, site_id)

    json(conn, funnel)
  end
end
