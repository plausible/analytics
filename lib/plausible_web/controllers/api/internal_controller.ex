defmodule PlausibleWeb.Api.InternalController do
  use Plausible
  use PlausibleWeb, :controller
  use Plausible.Repo
  alias Plausible.{Sites, Auth}
  alias Plausible.Auth.User
  alias Plausible.Teams

  def sites(conn, _params) do
    current_user = conn.assigns[:current_user]
    current_team = conn.assigns[:current_team]

    if current_user do
      sites =
        current_user
        |> Teams.Sites.list_for_switcher(current_team)
        |> Enum.map(&Map.take(&1, [:domain, :needs_verification]))

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
             Auth.super_admin?(user_id),
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

  def complete_onboarding(conn, %{"domain" => domain}) do
    with %User{} = user <- conn.assigns[:current_user],
         site <- Sites.get_by_domain(domain),
         true <- Teams.Memberships.has_editor_access?(site, user) do
      site
      |> Plausible.Site.put_onboarding_status_advance(:completed)
      |> Repo.update!()

      json(conn, "ok")
    else
      _ ->
        PlausibleWeb.Api.Helpers.unauthorized(
          conn,
          "You need to be logged in as the owner, admin, or editor of this site"
        )
    end
  end
end
