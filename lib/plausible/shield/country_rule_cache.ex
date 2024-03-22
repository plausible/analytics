defmodule Plausible.Shield.CountryRuleCache do
  @moduledoc """
  Allows retrieving Country Rules by domain and country code
  """
  alias Plausible.Shield.CountryRule

  import Ecto.Query
  use Plausible.Cache

  @cache_name :country_blocklist_by_domain

  @cached_schema_fields ~w(
    id
    country_code
    action
  )a

  @impl true
  def name(), do: @cache_name

  @impl true
  def child_id(), do: :cache_country_blocklist

  @impl true
  def count_all() do
    Plausible.Repo.aggregate(CountryRule, :count)
  end

  @impl true
  def base_db_query() do
    from rule in CountryRule,
      inner_join: s in assoc(rule, :site),
      select: {
        s.domain,
        s.domain_changed_from,
        %{struct(rule, ^@cached_schema_fields) | from_cache?: true}
      }
  end

  @impl true
  def get_from_source({domain, country_code}) do
    query =
      base_db_query()
      |> where([rule, site], rule.country_code == ^country_code and site.domain == ^domain)

    case Plausible.Repo.one(query) do
      {_, _, rule} -> %CountryRule{rule | from_cache?: false}
      _any -> nil
    end
  end

  @impl true
  def unwrap_cache_keys(items) do
    Enum.reduce(items, [], fn
      {domain, nil, object}, acc ->
        [{{domain, String.upcase(object.country_code)}, object} | acc]

      {domain, domain_changed_from, object}, acc ->
        [
          {{domain, String.upcase(object.country_code)}, object},
          {{domain_changed_from, String.upcase(object.country_code)}, object} | acc
        ]
    end)
  end
end
