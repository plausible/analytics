defmodule Plausible.IngestRepo.Migrations.CapitalizeKnownSources do
  use Ecto.Migration

  def up() do
    {:ok, _} = Application.ensure_all_started(:ref_inspector)
    [{"referers.yml", map}] = RefInspector.Database.list(:default)

    {downcased_sources, sources} =
      Enum.flat_map(map, fn {_, entries} ->
        Enum.map(entries, fn {_, _, _, _, _, _, name} -> name end)
      end)
      |> Enum.flat_map(fn name ->
        downcased_name = String.downcase(name)

        if name != downcased_name do
          [{downcased_name, name}]
        else
          []
        end
      end)
      |> Enum.unzip()

    events_sql = """
      ALTER TABLE events_v2
      UPDATE referrer_source = transform(referrer_source, {$0:Array(String)}, {$1:Array(String)})
      WHERE ascii(referrer_source) BETWEEN 97 AND 122
    """

    sessions_sql = """
      ALTER TABLE sessions_v2
      UPDATE referrer_source = transform(referrer_source, {$0:Array(String)}, {$1:Array(String)})
      WHERE ascii(referrer_source) BETWEEN 97 AND 122
    """

    execute(fn -> repo().query!(events_sql, [downcased_sources, sources]) end)
    execute(fn -> repo().query!(sessions_sql, [downcased_sources, sources]) end)
  end

  def down do
    raise "irreversible"
  end
end
