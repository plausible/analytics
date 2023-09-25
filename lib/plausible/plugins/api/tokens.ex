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
  def create(%Site{} = site, description) do
    with %{raw: raw, hash: hash} <- Token.generate(),
         changeset <- Token.insert_changeset(site, %{token_hash: hash, description: description}),
         {:ok, token} <- Repo.insert(changeset) do
      {:ok, token, raw}
    end
  end

  @spec find(String.t(), String.t()) :: {:ok, Token.t()} | {:error, :not_found}
  def find(domain, raw) do
    found =
      Repo.one(
        from(t in Token,
          inner_join: s in Site,
          on: s.id == t.site_id,
          where: t.token_hash == ^Token.hash(raw),
          where: s.domain == ^domain or s.domain_changed_from == ^domain,
          select: t
        )
      )

    if found do
      {:ok, found}
    else
      {:error, :not_found}
    end
  end
end
