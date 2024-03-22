defmodule Plausible.Plugins.API.CustomProps do
  @moduledoc """
  Plugins API context module for Custom Props.
  All high level Custom Props operations should be implemented here.
  """

  @spec enable(Plausible.Site.t(), String.t() | [String.t()]) ::
          {:ok, [String.t()]} | {:error, :upgrade_required | Ecto.Changeset.t()}
  def enable(site, prop_or_props) do
    case Plausible.Props.allow(site, prop_or_props) do
      {:ok, site} ->
        {:ok, site.allowed_event_props}

      error ->
        error
    end
  end

  @spec disable(Plausible.Site.t(), String.t() | [String.t()]) ::
          :ok | {:error, Ecto.Changeset.t()}
  def disable(site, prop_or_props) do
    case Plausible.Props.disallow(site, prop_or_props) do
      {:ok, _site} -> :ok
      error -> error
    end
  end
end
