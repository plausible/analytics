defmodule PlausibleWeb.SSO.RealSAMLAdapter do
  @moduledoc """
  Real implementation of SAML authentication interface.
  """
  alias Plausible.Auth.SSO

  alias PlausibleWeb.Router.Helpers, as: Routes

  @deflate "urn:oasis:names:tc:SAML:2.0:bindings:URL-Encoding:DEFLATE"

  @cookie_name "session_saml"
  @cookie_seconds 10 * 60

  def signin(conn, %{"integration_id" => integration_id} = params) do
    email = params["email"]
    return_to = params["return_to"]

    case SSO.get_integration(integration_id) do
      {:ok, integration} ->
        sp_entity_id = SSO.SAMLConfig.entity_id(integration)
        relay_state = gen_id()
        id = "saml_flow_#{gen_id()}"

        auth_xml = generate_auth_request(sp_entity_id, id, DateTime.utc_now())

        params = %{
          "SAMLEncoding" => @deflate,
          "SAMLRequest" => Base.encode64(:zlib.zip(auth_xml)),
          "RelayState" => relay_state,
          "login_hint" => email
        }

        url = %URI{} = URI.parse(integration.config.idp_signin_url)

        query_string =
          (url.query || "")
          |> URI.decode_query()
          |> Map.merge(params)
          |> URI.encode_query()

        url = URI.to_string(%{url | query: query_string})

        conn
        |> Plug.Conn.configure_session(renew: true)
        |> set_cookie(
          relay_state: relay_state,
          return_to: return_to
        )
        |> Phoenix.Controller.redirect(external: url)

      {:error, :not_found} ->
        conn
        |> Phoenix.Controller.put_flash(:login_error, "Wrong email.")
        |> Phoenix.Controller.redirect(
          to: Routes.sso_path(conn, :login_form, return_to: return_to)
        )
    end
  end

  def consume(conn, _params) do
    integration_id = conn.path_params["integration_id"]
    saml_response = conn.body_params["SAMLResponse"]
    relay_state = conn.body_params["RelayState"] |> safe_decode_www_form()

    case get_cookie(conn) do
      {:ok, cookie} ->
        conn
        |> clear_cookie()
        |> consume(integration_id, cookie, saml_response, relay_state)

      {:error, :session_expired} ->
        conn
        |> Phoenix.Controller.put_flash(:login_error, "Session expired.")
        |> Phoenix.Controller.redirect(to: Routes.sso_path(conn, :login_form))
    end
  end

  @verify_opts if Mix.env() == :test, do: [skip_time_conditions?: true], else: []

  defp consume(conn, integration_id, cookie, saml_response, relay_state) do
    with {:ok, integration} <- SSO.get_integration(integration_id),
         :ok <- validate_authresp(cookie, relay_state),
         {:ok, {root, assertion}} <- SimpleSaml.parse_response(saml_response),
         {:ok, cert} <- convert_pem_cert(integration.config.idp_cert_pem),
         public_key = X509.Certificate.public_key(cert),
         :ok <-
           SimpleSaml.verify_and_validate_response(root, assertion, public_key, @verify_opts),
         {:ok, attributes} <- extract_attributes(assertion) do
      session_timeout_minutes = integration.team.policy.sso_session_timeout_minutes

      expires_at =
        NaiveDateTime.add(NaiveDateTime.utc_now(:second), session_timeout_minutes, :minute)

      identity =
        %SSO.Identity{
          id: assertion.name_id,
          integration_id: integration.identifier,
          name: name_from_attributes(attributes),
          email: attributes.email,
          expires_at: expires_at
        }

      "sso_login_success"
      |> Plausible.Audit.Entry.new(identity, %{team_id: integration.team.id})
      |> Plausible.Audit.Entry.include_change(identity)
      |> Plausible.Audit.Entry.persist!()

      PlausibleWeb.UserAuth.log_in_user(conn, identity, cookie.return_to)
    else
      {:error, :not_found} ->
        login_error(conn, cookie, "Wrong email")

      {:error, reason} ->
        with {:ok, integration} <- SSO.get_integration(integration_id) do
          "sso_login_failure"
          |> Plausible.Audit.Entry.new(integration, %{team_id: integration.team.id})
          |> Plausible.Audit.Entry.include_change(%{
            error: inspect(reason)
          })
          |> Plausible.Audit.Entry.persist!()
        end

        login_error(conn, cookie, "Authentication failed (reason: #{inspect(reason)})")
    end
  end

  defp convert_pem_cert(cert) do
    case X509.Certificate.from_pem(cert) do
      {:ok, cert} -> {:ok, cert}
      {:error, _} -> {:error, :malformed_certificate}
    end
  end

  defp name_from_attributes(attributes) do
    [attributes.first_name, attributes.last_name]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
    |> String.trim()
  end

  defp extract_attributes(assertion) do
    attributes =
      Enum.reduce([:email, :first_name, :last_name], %{}, fn field, attrs ->
        value =
          assertion.attributes
          |> Map.get(to_string(field), [])
          |> List.first()

        Map.put(attrs, field, String.trim(value || ""))
      end)

    cond do
      attributes.email == "" ->
        {:error, :missing_email_attribute}

      # very rudimentary way to check if the attribute is at least email-like
      not String.contains?(attributes.email, "@") or String.length(attributes.email) < 3 ->
        {:error, :invalid_email_attribute}

      attributes.first_name == "" and attributes.last_name == "" ->
        {:error, :missing_name_attributes}

      true ->
        {:ok, attributes}
    end
  end

  defp safe_decode_www_form(nil), do: ""
  defp safe_decode_www_form(data), do: URI.decode_www_form(data)

  defp generate_auth_request(issuer_id, id, timestamp) do
    XmlBuilder.generate(
      {:"samlp:AuthnRequest",
       [
         "xmlns:samlp": "urn:oasis:names:tc:SAML:2.0:protocol",
         ID: id,
         Version: "2.0",
         IssueInstant: DateTime.to_iso8601(timestamp)
       ], [{:"saml:Issuer", ["xmlns:saml": "urn:oasis:names:tc:SAML:2.0:assertion"], issuer_id}]}
    )
  end

  defp validate_authresp(%{relay_state: relay_state}, relay_state)
       when byte_size(relay_state) == 32 do
    :ok
  end

  defp validate_authresp(_, _), do: {:error, :invalid_relay_state}

  defp gen_id() do
    24 |> :crypto.strong_rand_bytes() |> Base.url_encode64()
  end

  @doc false
  def set_cookie(conn, attrs) do
    attrs = %{
      relay_state: Keyword.fetch!(attrs, :relay_state),
      return_to: Keyword.fetch!(attrs, :return_to)
    }

    Plug.Conn.put_resp_cookie(conn, @cookie_name, attrs,
      domain: conn.private.phoenix_endpoint.host(),
      secure: true,
      encrypt: true,
      max_age: @cookie_seconds,
      same_site: "None"
    )
  end

  defp get_cookie(conn) do
    conn = Plug.Conn.fetch_cookies(conn, encrypted: [@cookie_name])

    if cookie = conn.cookies[@cookie_name] do
      {:ok, cookie}
    else
      {:error, :session_expired}
    end
  end

  defp clear_cookie(conn) do
    Plug.Conn.delete_resp_cookie(conn, @cookie_name,
      domain: conn.private.phoenix_endpoint.host(),
      secure: true,
      encrypt: true,
      max_age: @cookie_seconds,
      same_site: "None"
    )
  end

  defp login_error(conn, cookie, login_error) do
    conn
    |> Phoenix.Controller.put_flash(:login_error, login_error)
    |> Phoenix.Controller.redirect(
      to: Routes.sso_path(conn, :login_form, return_to: cookie.return_to)
    )
  end
end
