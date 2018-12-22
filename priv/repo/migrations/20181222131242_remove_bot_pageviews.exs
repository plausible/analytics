defmodule Neatmetrics.Repo.Migrations.RemoveBotPageviews do
  use Ecto.Migration
  use Neatmetrics.Repo

  def change do
    Application.ensure_all_started(:ua_inspector)

    for pageview <- Repo.all(Neatmetrics.Pageview) do
      is_bot = pageview.user_agent && UAInspector.bot?(pageview.user_agent)
      if is_bot do
        Repo.delete(pageview)
      end
    end
  end
end
