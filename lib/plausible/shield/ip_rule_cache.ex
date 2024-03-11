defmodule Plausible.Shield.IPRuleCache do
  @moduledoc """
  Allows retrieving IP Rules by domain and IP
  """
  alias Plausible.Shield.IPRule

  import Ecto.Query
  use Plausible.Cache

  @cache_name :ip_blocklist_by_domain

  @cached_schema_fields ~w(
    id
    inet
    action
  )a

  @impl true
  def name(), do: @cache_name

  @impl true
  def child_id(), do: :cache_ip_blocklist

  @impl true
  def count_all() do
    Plausible.Repo.aggregate(IPRule, :count)
  end

  @impl true
  def base_db_query() do
    from rule in IPRule,
      inner_join: s in assoc(rule, :site),
      select: {
        s.domain,
        s.domain_changed_from,
        %{struct(rule, ^@cached_schema_fields) | from_cache?: true}
      }
  end

  @impl true
  def get_from_source({domain, address}) do
    query =
      base_db_query()
      |> where([rule, site], rule.inet == ^address and site.domain == ^domain)

    case Plausible.Repo.one(query) do
      {_, _, rule} -> %IPRule{rule | from_cache?: false}
      _any -> nil
    end
  end

  @impl true
  def unwrap_cache_keys(items) do
    Enum.reduce(items, [], fn
      {domain, nil, object}, acc ->
        [{{domain, to_string(object.inet)}, object} | acc]

      {domain, domain_changed_from, object}, acc ->
        [
          {{domain, to_string(object.inet)}, object},
          {{domain_changed_from, to_string(object.inet)}, object} | acc
        ]
    end)
  end
end
