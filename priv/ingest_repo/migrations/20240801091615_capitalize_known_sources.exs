defmodule Plausible.IngestRepo.Migrations.CapitalizeKnownSources do
  use Ecto.Migration

  def up() do
    {:ok, _} = Application.ensure_all_started(:ref_inspector)
    [{"referers.yml", map}] = RefInspector.Database.list(:default)

    sources =
      Enum.flat_map(map, fn {_, entries} ->
        Enum.map(entries, fn {_, _, _, _, _, _, name} ->
          {String.downcase(name), name}
        end)
      end)
      |> Enum.into(%{})

    events_sql = """
      ALTER TABLE events_v2
      UPDATE referrer_source = {$0:Map(String, String)}[referrer_source]
      WHERE {$0:Map(String, String)}[referrer_source] != ''
    """

    sessions_sql = """
      ALTER TABLE sessions_v2
      UPDATE referrer_source = {$0:Map(String, String)}[referrer_source]
      WHERE {$0:Map(String, String)}[referrer_source] != ''
    """

    execute(fn -> repo().query!(events_sql, [sources]) end)
    execute(fn -> repo().query!(sessions_sql, [sources]) end)
  end

  def down do
    raise "irreversible"
  end
end
