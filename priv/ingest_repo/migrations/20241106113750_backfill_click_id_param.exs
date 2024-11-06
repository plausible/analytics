defmodule Plausible.IngestRepo.Migrations.BackfillClickIdParam do
  use Ecto.Migration

  def up do
    events_sql = """
      ALTER TABLE events_v2
      UPDATE click_id_param = transform(referrer_source, ['Google', 'Bing'], ['gclid', 'msclkid'], '')
      WHERE channel = 'Paid Search' AND click_id_param = ''
    """

    sessions_sql = """
      ALTER TABLE sessions_v2
      UPDATE click_id_param = transform(referrer_source, ['Google', 'Bing'], ['gclid', 'msclkid'], '')
      WHERE channel = 'Paid Search' AND click_id_param = ''
    """

    execute(fn -> repo().query!(events_sql) end)
    execute(fn -> repo().query!(sessions_sql) end)
  end

  def down do
    raise "irreversible"
  end
end
