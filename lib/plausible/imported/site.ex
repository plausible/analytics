defmodule Plausible.Imported do
  def forget(site) do
    Plausible.ClickhouseRepo.clear_imported_stats_for(site.domain)
  end
end
