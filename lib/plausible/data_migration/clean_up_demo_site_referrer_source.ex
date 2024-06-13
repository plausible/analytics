defmodule Plausible.DataMigration.CleanUpDemoSiteReferrerSource do
  @moduledoc """
  Clean up referrer_source entries for demo site with
  `Direct / None` for value populated by dogfooding
  Plausible stats.
  """

  alias Plausible.IngestRepo
  alias Plausible.Repo

  def run(timeout \\ 60_000) do
    demo_domain = PlausibleWeb.Endpoint.host()
    %{id: demo_site_id} = Repo.get_by(Plausible.Site, domain: demo_domain)

    for table <- ["sessions_v2", "events_v2"] do
      IngestRepo.query!(
        "ALTER TABLE {$0:Identifier} UPDATE referrer_source = '' WHERE " <>
          "site_id = {$1:UInt64} AND referrer_source = 'Direct / None'",
        [table, demo_site_id],
        settings: [mutations_sync: 1],
        timeout: timeout
      )
    end
  end
end
