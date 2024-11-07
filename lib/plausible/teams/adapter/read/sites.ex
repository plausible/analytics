defmodule Plausible.Teams.Adapter.Read.Sites do
  @moduledoc """
  Transition adapter for new schema reads 
  """
  import Ecto.Query
  alias Plausible.Repo
  alias Plausible.Site
  alias Plausible.Auth

  def list(user, pagination_params, opts \\ []) do
    if Plausible.Teams.read_team_schemas?(user) do
      Plausible.Teams.Sites.list(user, pagination_params, opts)
    else
      old_list(user, pagination_params, opts)
    end
  end

  def list_with_invitations(user, pagination_params, opts \\ []) do
    if Plausible.Teams.read_team_schemas?(user) do
      Plausible.Teams.Sites.list_with_invitations(user, pagination_params, opts)
    else
      old_list_with_invitations(user, pagination_params, opts)
    end
  end

  @type list_opt() :: {:filter_by_domain, String.t()}
  @spec old_list(Auth.User.t(), map(), [list_opt()]) :: Scrivener.Page.t()
  def old_list(user, pagination_params, opts \\ []) do
    domain_filter = Keyword.get(opts, :filter_by_domain)

    from(s in Site,
      left_join: up in Site.UserPreference,
      on: up.site_id == s.id and up.user_id == ^user.id,
      inner_join: sm in assoc(s, :memberships),
      on: sm.user_id == ^user.id,
      select: %{
        s
        | pinned_at: selected_as(up.pinned_at, :pinned_at),
          entry_type:
            selected_as(
              fragment(
                """
                CASE
                WHEN ? IS NOT NULL THEN 'pinned_site'
                ELSE 'site'
                END
                """,
                up.pinned_at
              ),
              :entry_type
            )
      },
      order_by: [asc: selected_as(:entry_type), desc: selected_as(:pinned_at), asc: s.domain],
      preload: [memberships: sm]
    )
    |> maybe_filter_by_domain(domain_filter)
    |> Repo.paginate(pagination_params)
  end

  @spec old_list_with_invitations(Auth.User.t(), map(), [list_opt()]) :: Scrivener.Page.t()
  def old_list_with_invitations(user, pagination_params, opts \\ []) do
    domain_filter = Keyword.get(opts, :filter_by_domain)

    result =
      from(s in Site,
        left_join: up in Site.UserPreference,
        on: up.site_id == s.id and up.user_id == ^user.id,
        left_join: i in assoc(s, :invitations),
        on: i.email == ^user.email,
        left_join: sm in assoc(s, :memberships),
        on: sm.user_id == ^user.id,
        where: not is_nil(sm.id) or not is_nil(i.id),
        select: %{
          s
          | pinned_at: selected_as(up.pinned_at, :pinned_at),
            entry_type:
              selected_as(
                fragment(
                  """
                  CASE
                  WHEN ? IS NOT NULL THEN 'invitation'
                  WHEN ? IS NOT NULL THEN 'pinned_site'
                  ELSE 'site'
                  END
                  """,
                  i.id,
                  up.pinned_at
                ),
                :entry_type
              )
        },
        order_by: [asc: selected_as(:entry_type), desc: selected_as(:pinned_at), asc: s.domain],
        preload: [memberships: sm, invitations: i]
      )
      |> maybe_filter_by_domain(domain_filter)
      |> Repo.paginate(pagination_params)

    # Populating `site` preload on `invitation`
    # without requesting it from database.
    # Necessary for invitation modals logic.
    entries =
      Enum.map(result.entries, fn
        %{invitations: [invitation]} = site ->
          site = %{site | invitations: [], memberships: []}
          invitation = %{invitation | site: site}
          %{site | invitations: [invitation]}

        site ->
          site
      end)

    %{result | entries: entries}
  end

  defp maybe_filter_by_domain(query, domain)
       when byte_size(domain) >= 1 and byte_size(domain) <= 64 do
    where(query, [s], ilike(s.domain, ^"%#{domain}%"))
  end

  defp maybe_filter_by_domain(query, _), do: query
end
