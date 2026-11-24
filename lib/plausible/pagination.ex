defmodule Plausible.Pagination do
  @moduledoc """
  Cursor-based pagination.
  """

  @limit 10
  @maximum_limit 100

  @spec paginate(Ecto.Queryable.t(), map(), Keyword.t(), Keyword.t()) :: Paginator.Page.t()
  def paginate(queryable, params, opts, repo_opts \\ []) do
    opts = Keyword.merge([limit: @limit, maximum_limit: @maximum_limit], opts)

    page =
      Paginator.paginate(
        queryable,
        Keyword.merge(opts, to_pagination_opts(params)),
        Plausible.Repo,
        repo_opts
      )

    %{
      page
      | metadata: %{
          page.metadata
          | after: sign_cursor(page.metadata.after),
            before: sign_cursor(page.metadata.before)
        }
    }
  end

  defp to_pagination_opts(params) do
    Enum.reduce(params, Keyword.new(), fn
      {"after", cursor}, acc ->
        put_verified_cursor(acc, :after, cursor)

      {"before", cursor}, acc ->
        put_verified_cursor(acc, :before, cursor)

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

  @cursor_salt "pagination cursor"

  defp sign_cursor(nil), do: nil

  defp sign_cursor(cursor) do
    Phoenix.Token.sign(PlausibleWeb.Endpoint, @cursor_salt, cursor)
  end

  defp put_verified_cursor(acc, key, signed_cursor) when is_binary(signed_cursor) do
    case Phoenix.Token.verify(PlausibleWeb.Endpoint, @cursor_salt, signed_cursor) do
      {:ok, cursor} -> Keyword.put(acc, key, cursor)
      {:error, _} -> raise ArgumentError, "invalid cursor"
    end
  end

  defp put_verified_cursor(_acc, _key, _signed_cursor) do
    raise ArgumentError, "invalid cursor"
  end

  defp to_int(x) when is_binary(x), do: String.to_integer(x)
  defp to_int(x) when is_integer(x), do: x
end
