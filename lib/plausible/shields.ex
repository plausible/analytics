defmodule Plausible.Shields do
  @moduledoc """
  Contextual interface for shields.
  """
  import Ecto.Query
  alias Plausible.Repo
  alias Plausible.Shield
  alias Plausible.Site

  @maximum_ip_rules 30
  def maximum_ip_rules(), do: @maximum_ip_rules

  @maximum_country_rules 30
  def maximum_country_rules(), do: @maximum_country_rules

  @spec list_ip_rules(Site.t() | non_neg_integer()) :: [Shield.IPRule.t()]
  def list_ip_rules(site_or_id) do
    list(Shield.IPRule, site_or_id)
  end

  @spec add_ip_rule(Site.t() | non_neg_integer(), map()) ::
          {:ok, Shield.IPRule.t()} | {:error, Ecto.Changeset.t()}
  def add_ip_rule(site_or_id, params) do
    add(Shield.IPRule, site_or_id, {:inet, @maximum_ip_rules}, params)
  end

  @spec remove_ip_rule(Site.t() | non_neg_integer(), String.t()) :: :ok
  def remove_ip_rule(site_or_id, rule_id) do
    remove(Shield.IPRule, site_or_id, rule_id)
  end

  @spec count_ip_rules(Site.t() | non_neg_integer()) :: non_neg_integer()
  def count_ip_rules(site_or_id) do
    count(Shield.IPRule, site_or_id)
  end

  @spec list_country_rules(Site.t() | non_neg_integer()) :: [Shield.CountryRule.t()]
  def list_country_rules(site_or_id) do
    list(Shield.CountryRule, site_or_id)
  end

  @spec add_country_rule(Site.t() | non_neg_integer(), map()) ::
          {:ok, Shield.CountryRule.t()} | {:error, Ecto.Changeset.t()}
  def add_country_rule(site_or_id, params) do
    add(Shield.CountryRule, site_or_id, {:country_code, @maximum_country_rules}, params)
  end

  @spec remove_country_rule(Site.t() | non_neg_integer(), String.t()) :: :ok
  def remove_country_rule(site_or_id, rule_id) do
    remove(Shield.CountryRule, site_or_id, rule_id)
  end

  @spec count_country_rules(Site.t() | non_neg_integer()) :: non_neg_integer()
  def count_country_rules(site_or_id) do
    count(Shield.CountryRule, site_or_id)
  end

  defp list(schema, %Site{id: id}) do
    list(schema, id)
  end

  defp list(schema, site_id) when is_integer(site_id) do
    Repo.all(
      from r in schema,
        where: r.site_id == ^site_id,
        order_by: [desc: r.inserted_at]
    )
  end

  defp add(schema, %Site{id: id}, max, params) do
    add(schema, id, max, params)
  end

  defp add(schema, site_id, {field, max}, params) when is_integer(site_id) do
    Repo.transaction(fn ->
      result =
        if count(schema, site_id) >= max do
          changeset =
            schema
            |> struct(site_id: site_id)
            |> schema.changeset(params)
            |> Ecto.Changeset.add_error(field, "maximum reached")

          {:error, changeset}
        else
          schema
          |> struct(site_id: site_id)
          |> schema.changeset(params)
          |> Repo.insert()
        end

      case result do
        {:ok, rule} -> rule
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp remove(schema, %Site{id: id}, rule_id) do
    remove(schema, id, rule_id)
  end

  defp remove(schema, site_id, rule_id) when is_integer(site_id) do
    Repo.delete_all(from(r in schema, where: r.site_id == ^site_id and r.id == ^rule_id))
    :ok
  end

  defp count(schema, %Site{id: id}) do
    count(schema, id)
  end

  defp count(schema, site_id) when is_integer(site_id) do
    Repo.aggregate(from(r in schema, where: r.site_id == ^site_id), :count)
  end
end
