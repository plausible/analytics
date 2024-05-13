defmodule Plausible.Imported.NoopImporter do
  @moduledoc """
  Stub import implementation.
  """

  use Plausible.Imported.Importer

  @impl true
  def name(), do: :noop

  @impl true
  def label(), do: "Noop"

  # reusing existing template from another source
  @impl true
  def email_template(), do: "google_analytics_import.html"

  @impl true
  def parse_args(opts), do: opts

  @impl true
  def import_data(_site_import, %{"error" => true}), do: {:error, "Something went wrong"}
  def import_data(_site_import, %{"crash" => true}), do: raise("boom")
  def import_data(_site_import, _opts), do: :ok

  @impl true
  def before_start(site_import, _opts) do
    send(self(), {:before_start, site_import.id})

    {:ok, site_import}
  end

  @impl true
  def on_success(site_import, _extra_data) do
    send(self(), {:on_success, site_import.id})

    :ok
  end

  @impl true
  def on_failure(site_import) do
    send(self(), {:on_failure, site_import.id})

    :ok
  end
end
