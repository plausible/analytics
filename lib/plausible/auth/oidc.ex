defmodule Plausible.Auth.OIDC do
  alias Plausible.Auth

  @default_role :viewer

  def use_oidc, do: Application.get_env(:plausible, Plausible.Auth.OIDC)[:enable]

  def get_or_create_user(claims) when is_map(claims),
    do: get_or_create_user(get_claim(claims, :email_claim), claims)

  def get_or_create_user(email, claims) when not is_nil(email),
    do: get_or_create_user(Auth.user_by_email(email), email, claims)

  def get_or_create_user({:ok, user}, _email, claims) do
    user =
      user
      |> Plausible.Repo.preload(:site_memberships)

    user = update_site_memberships(user, claims)

    {:ok, user}
  end

  def get_or_create_user({:error, :not_found}, email, claims) do
    email_verified = get_claim(claims, :email_verified_claim)
    name = get_claim(claims, :name_claim)

    user = Plausible.Auth.create_oidc_user(name, email, email_verified)

    user = update_site_memberships(user, claims)

    {:ok, user}
  end

  defp update_site_memberships(user, claims),
    do: update_site_memberships(user, claims, get_claim(claims, :site_membership_claim))

  defp update_site_memberships(user, _claims, nil), do: user

  defp update_site_memberships(user, _claims, sites) do
    wanted_sites =
      sites
      |> Enum.map(&get_site/1)
      |> Enum.filter(fn
        {nil, _} -> false
        {_, _} -> true
      end)
      |> Enum.map(fn {%{id: id}, v} -> {id, v} end)

    sites =
      user.site_memberships
      |> Enum.map(fn %{site_id: id, role: role} -> {id, role} end)

    delete_sites =
      sites
      |> Enum.filter(fn {id, role} -> !Enum.member?(wanted_sites, {id, role}) end)
      |> Enum.map(fn {id, _} -> id end)

    user.site_memberships
    |> Enum.filter(fn %{site_id: id} -> Enum.member?(delete_sites, id) end)
    |> Enum.map(&Plausible.Repo.delete/1)

    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    create_sites =
      wanted_sites
      |> Enum.filter(fn {id, role} -> !Enum.member?(sites, {id, role}) end)
      |> Enum.map(fn {id, role} ->
        %{site_id: id, role: role, user_id: user.id, inserted_at: now, updated_at: now}
      end)

    Plausible.Repo.insert_all(Plausible.Site.Membership, create_sites)

    user
  end

  defp get_site(domain) when is_binary(domain),
    do: {Plausible.Sites.get_by_domain(domain), @default_role}

  defp get_site({domain, role}) when is_binary(domain),
    do: {Plausible.Sites.get_by_domain(domain), get_role(role)}

  defp get_role(role) when is_atom(role), do: role
  defp get_role(role) when is_binary(role), do: String.to_existing_atom(role)

  defp get_claim(claims, fun) when is_map(claims) and is_atom(fun) do
    cfg_fun = Application.get_env(:plausible, Plausible.Auth.ODIC)[fun]
    get_claim(fun, cfg_fun, claims)
  end

  defp get_claim(fun, nil, claims), do: apply(__MODULE__, fun, [claims])
  defp get_claim(_, fun, claims), do: apply(fun, [claims])

  @doc false
  def email_claim(%{"email" => email}), do: email

  @doc false
  def email_verified_claim(%{"email_verified" => verified}), do: verified
  def email_verified_claim(_), do: false

  @doc false
  def name_claim(%{"preferred_username" => name}), do: name
  def name_claim(_), do: nil

  @doc false
  def site_membership_claim(_), do: nil
end
