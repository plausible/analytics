defmodule PlausibleWeb.Api.CustomerSupport.SiteController do
  @moduledoc """
  Site changes from the CS admin site page: the ingest rate limit, the native
  stats start date, and starting an ownership transfer from the Rescue zone.

  Every request names the site's domain as well as its id, so a mistyped id
  can't change another site.
  """
  use PlausibleWeb, :controller
  use Plausible.Repo

  alias PlausibleWeb.Api.CustomerSupport.Helpers, as: H

  @rate_limit_fields ["ingest_rate_limit_threshold", "ingest_rate_limit_scale_seconds"]

  @doc """
  Sets the ingest rate limit. `ingest_rate_limit_threshold` is the number of
  events allowed per `ingest_rate_limit_scale_seconds`; `null` removes the
  limit and `0` blocks all traffic, as in the CS admin.
  """
  def rate_limit(conn, params) do
    H.run_site_action(conn, params, "site_rate_limit_updated", fn site ->
      with :ok <-
             H.guard(
               Enum.all?(@rate_limit_fields, &Map.has_key?(params, &1)),
               "Parameters `ingest_rate_limit_threshold` and `ingest_rate_limit_scale_seconds` are required"
             ),
           {:ok, site} <-
             site
             |> Plausible.Site.crm_changeset(Map.take(params, @rate_limit_fields))
             |> Repo.update() do
        {:ok, site,
         %{
           domain: site.domain,
           ingest_rate_limit_threshold: site.ingest_rate_limit_threshold,
           ingest_rate_limit_scale_seconds: site.ingest_rate_limit_scale_seconds
         }}
      end
    end)
  end

  @doc """
  Sets the native stats start date (`native_stats_start_at`, an ISO 8601 date
  and time in UTC): where imported data stops and the site's own stats begin.
  Used to help a customer fit a Google Analytics import around their stats.
  """
  def native_stats_start(conn, params) do
    H.run_site_action(conn, params, "site_native_stats_start_updated", fn site ->
      with :ok <-
             H.guard(
               is_binary(params["native_stats_start_at"]),
               "Parameter `native_stats_start_at` is required"
             ),
           {:ok, site} <-
             site
             |> Plausible.Site.crm_changeset(Map.take(params, ["native_stats_start_at"]))
             |> Repo.update() do
        {:ok, site, %{domain: site.domain, native_stats_start_at: site.native_stats_start_at}}
      end
    end)
  end

  @doc """
  Starts an ownership transfer: sends the transfer email to `invitee_email`
  on behalf of `inviter_email`, as the CS admin's Rescue zone does. The
  inviter must be an owner or admin of the site's team; the transfer only
  happens once the invitee accepts it.
  """
  def transfer(conn, params) do
    H.run_site_action(conn, params, "site_transfer_started", fn site ->
      with {:ok, inviter} <- fetch_user_by_email(params["inviter_email"], "inviter_email"),
           :ok <-
             H.guard(
               is_binary(params["invitee_email"]) and params["invitee_email"] != "",
               "Parameter `invitee_email` is required"
             ),
           {:ok, _transfer} <- invite(site, inviter, params["invitee_email"]) do
        {:ok, site,
         %{
           domain: site.domain,
           inviter_email: inviter.email,
           invitee_email: params["invitee_email"]
         }}
      end
    end)
  end

  defp invite(site, inviter, invitee_email) do
    case Plausible.Teams.Invitations.InviteToSite.invite(site, inviter, invitee_email, :owner) do
      {:ok, transfer} -> {:ok, transfer}
      {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset}
      {:error, reason} -> {:error, :guard, "Transfer refused: #{inspect(reason)}"}
    end
  end

  defp fetch_user_by_email(email, param) when is_binary(email) and email != "" do
    case Plausible.Auth.find_user_by(email: String.trim(email)) do
      %Plausible.Auth.User{} = user -> {:ok, user}
      nil -> {:error, :guard, "No user with that `#{param}`"}
    end
  end

  defp fetch_user_by_email(_email, param),
    do: {:error, :guard, "Parameter `#{param}` is required"}
end
