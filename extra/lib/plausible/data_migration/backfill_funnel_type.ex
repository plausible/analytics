defmodule Plausible.DataMigration.BackfillFunnelType do
  @moduledoc """
  Backfill and sync funnel_type for all funnels out of sync.
  """

  import Ecto.Query

  alias Plausible.Funnel
  alias Plausible.Repo

  def run(opts \\ []) do
    dry_run? = Keyword.get(opts, :dry_run?, true)

    log("DRY RUN: #{dry_run?}")

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

    log("Found #{length(out_of_sync_funnels)} funnels with funnel_type out of sync...")

    if not dry_run? do
      Enum.each(out_of_sync_funnels, fn funnel ->
        funnel
        |> set_funnel_type()
        |> Repo.update!()
      end)

      log("Finished syncing funnel type for #{length(out_of_sync_funnels)} funnels!")
    end

    :ok
  end

  defp set_funnel_type(%{strict_order: false, first_and_last: false} = funnel) do
    Ecto.Changeset.change(funnel, funnel_type: :sequential)
  end

  defp set_funnel_type(%{strict_order: true, first_and_last: false} = funnel) do
    Ecto.Changeset.change(funnel, funnel_type: :strict)
  end

  defp set_funnel_type(%{strict_order: false, first_and_last: true} = funnel) do
    Ecto.Changeset.change(funnel, funnel_type: :flexible)
  end

  defp log(msg) do
    IO.puts("[#{DateTime.utc_now(:second)}] #{msg}")
  end
end
