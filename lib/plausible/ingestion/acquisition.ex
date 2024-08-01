defmodule Plausible.Ingestion.Acquisition do
  def init() do
    :ets.new(__MODULE__, [
      :named_table,
      :set,
      :public,
      {:read_concurrency, true}
    ])

    [{"referers.yml", map}] = RefInspector.Database.list(:default)

    Enum.flat_map(map, fn {_, entries} ->
      Enum.map(entries, fn {_, _, _, _, _, _, name} ->
        :ets.insert(__MODULE__, {String.downcase(name), name})
      end)
    end)
  end

  def find_mapping(source) do
    case :ets.lookup(__MODULE__, source) do
      [{_, name}] -> name
      _ -> source
    end
  end
end
