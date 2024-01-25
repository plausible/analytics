defmodule Plausible.Imported.NoopImporter do
  @moduledoc """
  Stub import implementation.
  """

  use Plausible.Imported.Importer

  @name "Noop"

  @impl true
  def name(), do: @name

  @impl true
  def parse_args(opts), do: opts

  @impl true
  def import_data(_site_import, %{"error" => true}), do: {:error, "Something went wrong"}
  def import_data(_site_import, _opts), do: :ok

  @impl true
  def before_start(site_import) do
    send(self(), {:before_start, site_import.id})

    :ok
  end

  @impl true
  def on_success(site_import) do
    send(self(), {:on_success, site_import.id})

    :ok
  end

  @impl true
  def on_failure(site_import) do
    send(self(), {:on_failure, site_import.id})

    :ok
  end
end
