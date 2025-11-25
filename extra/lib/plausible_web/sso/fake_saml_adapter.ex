defmodule PlausibleWeb.SSO.FakeSAMLAdapter do
  @moduledoc """
  Fake implementation of SAML authentication interface.
  """

  alias Plausible.Auth
  alias Plausible.Auth.SSO
  alias Plausible.Repo

  alias PlausibleWeb.Router.Helpers, as: Routes

  def signin(conn, params) do
    conn
    |> Phoenix.Controller.put_layout(false)
    |> Phoenix.Controller.render("saml_signin.html",
      integration_id: params["integration_id"],
      email: params["email"],
      return_to: params["return_to"],
      nonce: conn.private[:sso_nonce]
    )
  end

  def consume(conn, params) do
    case SSO.get_integration(params["integration_id"]) do
      {:ok, integration} ->
        session_timeout_minutes = integration.team.policy.sso_session_timeout_minutes

        expires_at =
          NaiveDateTime.add(NaiveDateTime.utc_now(:second), session_timeout_minutes, :minute)

        identity =
          if user = Repo.get_by(Auth.User, email: params["email"]) do
            %SSO.Identity{
              id: user.sso_identity_id || Ecto.UUID.generate(),
              integration_id: integration.identifier,
              name: user.name,
              email: user.email,
              expires_at: expires_at
            }
          else
            %SSO.Identity{
              id: Ecto.UUID.generate(),
              integration_id: integration.identifier,
              name: name_from_email(params["email"]),
              email: params["email"],
              expires_at: expires_at
            }
          end

        "sso_login_success"
        |> Plausible.Audit.Entry.new(identity, %{team_id: integration.team.id})
        |> Plausible.Audit.Entry.include_change(identity)
        |> Plausible.Audit.Entry.persist!()

        PlausibleWeb.UserAuth.log_in_user(conn, identity, params["return_to"])

      {:error, :not_found} ->
        conn
        |> Phoenix.Controller.put_flash(:login_error, "Wrong email.")
        |> Phoenix.Controller.redirect(
          to: Routes.sso_path(conn, :login_form, return_to: params["return_to"])
        )
    end
  end

  defp name_from_email(email) do
    email
    |> String.split("@", parts: 2)
    |> List.first()
    |> String.split(".")
    |> Enum.take(2)
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
