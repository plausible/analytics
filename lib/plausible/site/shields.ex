defmodule Plausible.Site.Shields do
  import Ecto.Query
  alias Plausible.Repo
  alias Plausible.Site.Shield.Rules

  @spec list_ip_rules(Plausible.Site.t()) :: [Rules.IP.t()]
  def list_ip_rules(site) do
    Repo.all(from r in Rules.IP, where: r.site_id == ^site.id)
  end

  @spec add_rule(Plausible.Site.t(), map()) :: {:ok, Rules.IP.t()} | {:error, Ecto.Changeset.t()}
  def add_rule(site, params) do
    %Rules.IP{}
    |> Rules.IP.changeset(Map.put(params, "site_id", site.id))
    |> Repo.insert()
  end
end
