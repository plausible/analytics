defmodule PlausibleWeb.Api.CustomerSupport.UserController do
  @moduledoc """
  Turns off two-factor authentication for a user locked out of their own
  account, as the Force Disable 2FA button on the CS admin user page does.

  The request names the user's email as well as their id, so a mistyped id
  can't turn 2FA off on someone else's account. Nothing else about the user
  changes: they log in with their password and can set 2FA up again.
  """
  use PlausibleWeb, :controller

  alias PlausibleWeb.Api.CustomerSupport.Helpers, as: H

  @daily_limit 5

  def disable_2fa(conn, params) do
    H.run_user_action(
      conn,
      params,
      "user_2fa_disabled",
      fn user ->
        with :ok <-
               H.guard(email_matches?(user, params["email"]), "Email doesn't match the user"),
             :ok <- H.guard(user.totp_enabled, "Two-factor authentication isn't enabled"),
             {:ok, user} <- Plausible.Auth.TOTP.force_disable(user) do
          {:ok, user, %{user_id: user.id, email: user.email, totp_enabled: false}}
        end
      end,
      limit: @daily_limit
    )
  end

  defp email_matches?(user, email) when is_binary(email) do
    String.downcase(String.trim(email)) == String.downcase(user.email)
  end

  defp email_matches?(_user, _email), do: false
end
