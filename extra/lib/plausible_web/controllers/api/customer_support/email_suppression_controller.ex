defmodule PlausibleWeb.Api.CustomerSupport.EmailSuppressionController do
  @moduledoc """
  Reactivates a suppressed email address, as the Reactivate button on the
  CS admin's email suppressions page does.
  """
  use PlausibleWeb, :controller

  alias PlausibleWeb.Api.CustomerSupport.Helpers, as: H

  def reactivate_suppression(conn, params) do
    H.run_action(
      conn,
      params,
      "email_reactivated",
      fn ->
        case H.fetch_suppression(params["email"]) do
          %Plausible.EmailSuppression{} = suppression -> {:ok, suppression}
          nil -> {:error, :not_found, "No suppression for this address"}
        end
      end,
      fn suppression ->
        with :ok <- H.guard(is_nil(suppression.reactivated_at), "Already reactivated"),
             {:ok, suppression} <- reactivate(suppression, conn.assigns.current_user) do
          {:ok, suppression, %{email: suppression.email, reactivated: true}}
        end
      end
    )
  end

  defp reactivate(suppression, user) do
    case Plausible.EmailSuppressions.reactivate(suppression.email, user) do
      {:ok, suppression} ->
        {:ok, suppression}

      {:error, :cannot_delete_spam_complaint} ->
        {:error, :guard, "A spam complaint can't be reactivated"}

      {:error, %Ecto.Changeset{}} = error ->
        error

      {:error, reason} ->
        {:error, :guard, "Reactivation failed: #{inspect(reason)}"}
    end
  end
end
