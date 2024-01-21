defmodule Plausible.Auth.OIDC do
  alias Plausible.Auth

  def use_oidc, do: Application.get_env(:plausible, Plausible.Auth.OIDC)[:enable]

  def get_or_create_user(claims) when is_map(claims),
    do: get_or_create_user(get_claim(claims, :email_claim), claims)

  def get_or_create_user(email, claims) when not is_nil(email),
    do: get_or_create_user(Auth.user_by_email(email), email, claims)

  def get_or_create_user({:ok, user}, email, claims) do
    # TODO: update site membership

    {:ok, user}
  end

  def get_or_create_user({:error, :not_found}, email, claims) do
    email_verified = get_claim(claims, :email_verified_claim)
    name = get_claim(claims, :name_claim)

    user = Plausible.Auth.create_oidc_user(name, email, email_verified)

    # TODO: update site memberships

    {:ok, user}
  end

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
end
