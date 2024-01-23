defmodule Plausible.Imported.NoopImporter do
  @moduledoc """
  Stub import implementation.
  """

  @name "Noop"

  def name(), do: @name

  def create_job(site, opts) do
    Plausible.Workers.ImportAnalytics.new(%{
      "source" => @name,
      "site_id" => site.id,
      "error" => opts[:error]
    })
  end

  def parse_args(opts), do: opts

  def import(_site, %{"error" => true}), do: {:error, "Something went wrong"}
  def import(_site, _opts), do: :ok
end
