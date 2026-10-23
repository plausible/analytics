defmodule PlausibleWeb.Api.CustomerSupport.UserController do
  @moduledoc """
  User changes from the CS admin user page: Force Disable 2FA for a user
  locked out of their own account, changing a user's login email, and
  deleting a user.

  Every request names the user's current email as well as their id, so a
  mistyped id can't touch someone else's account.
  """
  use PlausibleWeb, :controller

  alias PlausibleWeb.Api.CustomerSupport.Helpers, as: H

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
      end
    )
  end

  @doc """
  Changes the user's login email to `new_email`, as saving a new email on the
  CS admin user page does: the email changes and nothing else (no
  verification step and no email to the user). The Paddle billing email is
  separate and stays as it is.
  """
  def change_email(conn, params) do
    H.run_user_action(conn, params, "user_email_changed", fn user ->
      new_email = params["new_email"]

      with :ok <- H.guard(email_matches?(user, params["email"]), "Email doesn't match the user"),
           :ok <-
             H.guard(
               is_binary(new_email) and String.trim(new_email) != "",
               "Parameter `new_email` is required"
             ),
           :ok <-
             H.guard(not email_matches?(user, new_email), "The new email is the same as the old"),
           {:ok, user} <-
             user
             |> Plausible.Auth.User.changeset(%{"email" => String.trim(new_email)})
             |> Plausible.Repo.update() do
        {:ok, user, %{user_id: user.id, email: user.email}}
      end
    end)
  end

  @doc """
  Deletes a user, as Delete User on the CS admin user page does (for a GDPR
  removal request, say). It runs `Plausible.Auth.delete_user/1`, so the same
  rules apply: a user whose team still has an active subscription, or who is
  the only owner of a team with other members, is refused.
  """
  def delete(conn, params) do
    H.run_user_action(
      conn,
      params,
      "user_deleted",
      fn user ->
        with :ok <-
               H.guard(email_matches?(user, params["email"]), "Email doesn't match the user"),
             :ok <- delete_user(user) do
          {:ok, user, %{user_id: user.id, email: user.email, deleted: true}}
        end
      end,
      deletion: true
    )
  end

  defp delete_user(user) do
    case Plausible.Auth.delete_user(user) do
      {:ok, _} ->
        :ok

      {:error, :active_subscription} ->
        {:error, :guard, "The user's team has an active subscription"}

      {:error, reason} ->
        {:error, :guard, "The user can't be deleted: #{inspect(reason)}"}
    end
  end

  defp email_matches?(user, email) when is_binary(email) do
    String.downcase(String.trim(email)) == String.downcase(user.email)
  end

  defp email_matches?(_user, _email), do: false
end
