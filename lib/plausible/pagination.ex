defmodule Plausible.Pagination do
  @moduledoc """
  Cursor-based pagination.
  """

  @limit 10
  @maximum_limit 100

  @spec paginate(Ecto.Queryable.t(), map(), Keyword.t(), Keyword.t()) :: Paginator.Page.t()
  def paginate(queryable, params, opts, repo_opts \\ []) do
    opts = Keyword.merge([limit: @limit, maximum_limit: @maximum_limit], opts)

    Paginator.paginate(
      queryable,
      Keyword.merge(opts, to_pagination_opts(params)),
      Plausible.Repo,
      repo_opts
    )
  end

  defp to_pagination_opts(params) do
    Enum.reduce(params, Keyword.new(), fn
      {"after", cursor}, acc ->
        Keyword.put(acc, :after, cursor)

      {"before", cursor}, acc ->
        Keyword.put(acc, :before, cursor)

      {"limit", limit}, acc ->
        limit = to_int(limit)

        if limit > 0 and limit <= @maximum_limit do
          Keyword.put(acc, :limit, limit)
        else
          acc
        end

      _, acc ->
        acc
    end)
  end

  defp to_int(x) when is_binary(x), do: String.to_integer(x)
  defp to_int(x) when is_integer(x), do: x
end
