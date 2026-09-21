defmodule Plausible.DataMigration.BackfillFunnelType do
  @moduledoc """
  Backfill and sync funnel_type for all funnels out of sync.
  """

  import Ecto.Query

  alias Plausible.Funnel
  alias Plausible.Repo

  def run(opts \\ []) do
    dry_run? = Keyword.get(opts, :dry_run?, true)
    backfill(dry_run?)
  end

  defp backfill(dry_run?) do
    out_of_sync_funnels =
      from(
        f in Funnel,
        where:
          (f.strict_order == false and f.first_and_last == false and f.funnel_type != :sequential) or
            (f.strict_order == true and f.funnel_type != :strict) or
            (f.first_and_last == true and f.funnel_type != :flexible)
      )
      |> Repo.all()

    log("Found #{length(out_of_sync_funnels)} with funnel_type out of sync...")

    if not dry_run? do
      Enum.each(out_of_sync_funnels, fn funnel ->
        funnel
        |> Ecto.Changeset.change()
        |> Funnel.set_funnel_type()
        |> Repo.update!()
      end)

      log("Finished syncing funnel type for  #{length(out_of_sync_funnels)} funnels...")
    end
  end

  defp log(msg) do
    IO.puts("[#{DateTime.utc_now(:second)}] #{msg}")
  end
end
