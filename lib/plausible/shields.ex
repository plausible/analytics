defmodule Plausible.Shields do
  @moduledoc """
  Contextual interface for shields.
  """
  import Ecto.Query
  alias Plausible.Repo
  alias Plausible.Shield

  @maximum_ip_rules 30
  def maximum_ip_rules(), do: @maximum_ip_rules

  @maximum_country_rules 15
  def maximum_country_rules(), do: @maximum_country_rules

  @spec list_ip_rules(Plausible.Site.t() | non_neg_integer()) :: [Shield.IPRule.t()]
  def list_ip_rules(site_id) when is_integer(site_id) do
    list(Shield.IPRule, site_id)
  end

  def list_ip_rules(%Plausible.Site{id: id}) do
    list_ip_rules(id)
  end

  @spec add_ip_rule(Plausible.Site.t() | non_neg_integer(), map()) ::
          {:ok, Shield.IPRule.t()} | {:error, Ecto.Changeset.t()}
  def add_ip_rule(site_id, params) when is_integer(site_id) do
    add(Shield.IPRule, site_id, {:inet, @maximum_ip_rules}, params)
  end

  def add_ip_rule(%Plausible.Site{id: id}, params) do
    add_ip_rule(id, params)
  end

  @spec remove_ip_rule(Plausible.Site.t() | non_neg_integer(), String.t()) :: :ok
  def remove_ip_rule(site_id, rule_id) when is_integer(site_id) do
    remove(Shield.IPRule, site_id, rule_id)
  end

  def remove_ip_rule(%Plausible.Site{id: site_id}, rule_id) do
    remove_ip_rule(site_id, rule_id)
  end

  @spec count_ip_rules(Plausible.Site.t() | non_neg_integer()) :: non_neg_integer()
  def count_ip_rules(site_id) when is_integer(site_id) do
    count(Shield.IPRule, site_id)
  end

  def count_ip_rules(%Plausible.Site{id: id}) do
    count_ip_rules(id)
  end

  @spec list_country_rules(Plausible.Site.t() | non_neg_integer()) :: [Shield.CountryRule.t()]
  def list_country_rules(site_id) when is_integer(site_id) do
    list(Shield.CountryRule, site_id)
  end

  def list_country_rules(%Plausible.Site{id: id}) do
    list_country_rules(id)
  end

  @spec add_country_rule(Plausible.Site.t() | non_neg_integer(), map()) ::
          {:ok, Shield.CountryRule.t()} | {:error, Ecto.Changeset.t()}
  def add_country_rule(site_id, params) when is_integer(site_id) do
    add(Shield.CountryRule, site_id, {:country_code, @maximum_country_rules}, params)
  end

  def add_country_rule(%Plausible.Site{id: id}, params) do
    add_country_rule(id, params)
  end

  @spec remove_country_rule(Plausible.Site.t() | non_neg_integer(), String.t()) :: :ok
  def remove_country_rule(site_id, rule_id) when is_integer(site_id) do
    remove(Shield.CountryRule, site_id, rule_id)
  end

  def remove_country_rule(%Plausible.Site{id: site_id}, rule_id) do
    remove_country_rule(site_id, rule_id)
  end

  @spec count_country_rules(Plausible.Site.t() | non_neg_integer()) :: non_neg_integer()
  def count_country_rules(site_id) when is_integer(site_id) do
    count(Shield.CountryRule, site_id)
  end

  def count_country_rules(%Plausible.Site{id: id}) do
    count_country_rules(id)
  end

  defp list(schema, site_id) do
    Repo.all(
      from r in schema,
        where: r.site_id == ^site_id,
        order_by: [desc: r.inserted_at]
    )
  end

  defp add(schema, site_id, {field, max}, params) do
    Repo.transaction(fn ->
      result =
        if count(schema, site_id) >= max do
          changeset =
            schema
            |> struct()
            |> schema.changeset(Map.put(params, "site_id", site_id))
            |> Ecto.Changeset.add_error(field, "maximum reached")

          {:error, changeset}
        else
          schema
          |> struct()
          |> schema.changeset(Map.put(params, "site_id", site_id))
          |> Repo.insert()
        end

      case result do
        {:ok, rule} -> rule
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp remove(schema, site_id, rule_id) do
    Repo.delete_all(from(r in schema, where: r.site_id == ^site_id and r.id == ^rule_id))
    :ok
  end

  defp count(schema, site_id) do
    Repo.aggregate(from(r in schema, where: r.site_id == ^site_id), :count)
  end
end
