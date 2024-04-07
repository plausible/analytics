defmodule Plausible.Shield.HostnameRuleCache do
  @moduledoc """
  Allows retrieving Hostname Rules by domain
  """
  alias Plausible.Shield.HostnameRule

  import Ecto.Query
  use Plausible.Cache

  @cache_name :hostname_allowlist_by_domain

  @cached_schema_fields ~w(
    id
    hostname_pattern
    action
  )a

  @impl true
  def name(), do: @cache_name

  @impl true
  def child_id(), do: :cache_hostname_blocklist

  @impl true
  def count_all() do
    Plausible.Repo.aggregate(HostnameRule, :count)
  end

  @impl true
  def base_db_query() do
    from rule in HostnameRule,
      inner_join: s in assoc(rule, :site),
      select: {
        s.domain,
        s.domain_changed_from,
        %{struct(rule, ^@cached_schema_fields) | from_cache?: true}
      }
  end

  @impl true
  def get_from_source(domain) do
    query =
      base_db_query()
      |> where([..., site], site.domain == ^domain)

    case Plausible.Repo.all(query) do
      [_ | _] = results ->
        Enum.map(results, fn {_, _, rule} ->
          %HostnameRule{rule | from_cache?: false}
        end)

      _ ->
        nil
    end
  end

  @impl true
  def unwrap_cache_keys(items) do
    Enum.reduce(items, [], fn
      {domain, nil, object}, acc ->
        [{domain, object} | acc]

      {domain, domain_changed_from, object}, acc ->
        [
          {domain, object},
          {domain_changed_from, object} | acc
        ]
    end)
  end
end
