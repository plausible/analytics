defmodule Plausible.Ingestion.Session.Registry do
  def child_spec do
    Registry.child_spec(keys: :unique, name: __MODULE__, partitions: System.schedulers_online())
  end
end
