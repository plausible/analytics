defmodule PlausibleWeb.Api.InternalController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  alias Plausible.{Sites, Auth}
  alias Plausible.Auth.User

  def sites(conn, _params) do
    current_user = conn.assigns[:current_user]
    current_team = conn.assigns[:current_team]

    if current_user do
      sites = sites_for(current_user, current_team)

      json(conn, %{data: sites})
    else
      PlausibleWeb.Api.Helpers.unauthorized(
        conn,
        "You need to be logged in to request a list of sites"
      )
    end
  end

  @features %{
    "funnels" => Plausible.Billing.Feature.Funnels,
    "props" => Plausible.Billing.Feature.Props,
    "conversions" => Plausible.Billing.Feature.Goals
  }
  def disable_feature(conn, %{"domain" => domain, "feature" => feature}) do
    with %User{id: user_id} = user <- conn.assigns[:current_user],
         site <- Sites.get_by_domain(domain),
         true <-
           Plausible.Teams.Memberships.has_editor_access?(site, user) ||
             Auth.is_super_admin?(user_id),
         {:ok, mod} <- Map.fetch(@features, feature),
         {:ok, _site} <- mod.toggle(site, user, override: false) do
      json(conn, "ok")
    else
      {:error, :upgrade_required} ->
        PlausibleWeb.Api.Helpers.payment_required(
          conn,
          "This feature is part of the Plausible Business plan. To get access to this feature, please upgrade your account"
        )

      :error ->
        PlausibleWeb.Api.Helpers.bad_request(
          conn,
          "The feature you tried to disable is not valid. Valid features are: #{@features |> Map.keys() |> Enum.join(", ")}"
        )

      _ ->
        PlausibleWeb.Api.Helpers.unauthorized(
          conn,
          "You need to be logged in as the owner or admin account of this site"
        )
    end
  end

  defp sites_for(user, team) do
    pagination = Sites.list(user, %{page_size: 9}, team: team)
    Enum.map(pagination.entries, &%{domain: &1.domain})
  end
end
