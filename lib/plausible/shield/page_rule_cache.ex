defmodule Plausible.Shield.PageRuleCache do
  @moduledoc """
  Allows retrieving Page Rules by domain
  """
  alias Plausible.Shield.PageRule

  import Ecto.Query
  use Plausible.Cache

  @cache_name :page_blocklist_by_domain

  @cached_schema_fields ~w(
    id
    page_path_pattern
    action
  )a

  @impl true
  def name(), do: @cache_name

  @impl true
  def child_id(), do: :cache_page_blocklist

  @impl true
  def count_all() do
    Plausible.Repo.aggregate(PageRule, :count)
  end

  @impl true
  def base_db_query() do
    from rule in PageRule,
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

    case Plausible.Repo.one(query) do
      {_, _, rule} -> %PageRule{rule | from_cache?: false}
      _any -> nil
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
