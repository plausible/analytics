defmodule Plausible.IngestRepo.Migrations.BackfillUtmMediumClickIdParam do
  @moduledoc """
  Backfills utm_medium based on referrer_source and click_id_param
  """
  use Ecto.Migration

  def up do
    execute(fn -> repo().query!(update_query("events_v2")) end)
    execute(fn -> repo().query!(update_query("sessions_v2")) end)
  end

  def down do
    raise "irreversible"
  end

  defp update_query(table) do
    """
    ALTER TABLE #{table}
    UPDATE utm_medium = multiIf(
      referrer_source = 'Google' AND click_id_param = 'gclid', '(gclid)',
      referrer_source = 'Bing' AND click_id_param = 'msclkid', '(msclkid)',
      utm_medium
    )
    WHERE empty(utm_medium) AND NOT empty(click_id_param)
    """
  end
end
