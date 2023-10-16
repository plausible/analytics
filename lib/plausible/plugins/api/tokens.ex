defmodule Plausible.Plugins.API.Tokens do
  @moduledoc """
  Context module for Plugins API Tokens.
  Exposes high-level operation for token-based authentication flows.
  """
  alias Plausible.Plugins.API.Token
  alias Plausible.Site
  alias Plausible.Repo

  import Ecto.Query

  @spec create(Site.t(), String.t()) ::
          {:ok, Token.t(), String.t()} | {:error, Ecto.Changeset.t()}
  def create(%Site{} = site, description, generated_token \\ Token.generate()) do
    with changeset <- Token.insert_changeset(site, generated_token, %{description: description}),
         {:ok, saved_token} <- Repo.insert(changeset) do
      {:ok, saved_token, generated_token.raw}
    end
  end

  @spec find(String.t()) :: {:ok, Token.t()} | {:error, :not_found}
  def find(raw) do
    found =
      Repo.one(
        from(t in Token,
          inner_join: s in Site,
          on: s.id == t.site_id,
          where: t.token_hash == ^Token.hash(raw),
          preload: [:site]
        )
      )

    if found do
      {:ok, found}
    else
      {:error, :not_found}
    end
  end

  @spec delete(Site.t(), String.t()) :: :ok
  def delete(site, token_id) do
    Repo.delete_all(from t in Token, where: t.site_id == ^site.id and t.id == ^token_id)
    :ok
  end

  @spec list(Site.t()) :: {:ok, [Token.t()]}
  def list(site) do
    Repo.all(from t in Token, where: t.site_id == ^site.id, order_by: [desc: t.id])
  end

  @spec any?(Site.t()) :: boolean()
  def any?(site) do
    Repo.aggregate(from(t in Token, where: t.site_id == ^site.id), :count) > 0
  end
end
