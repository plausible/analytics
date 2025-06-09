defmodule PlausibleWeb.SSO.RealSAMLAdapter do
  @moduledoc """
  Real implementation of SAML authentication interface.
  """
  alias Plausible.Auth.SSO
  alias SimpleXml.XmlNode

  alias PlausibleWeb.Router.Helpers, as: Routes

  @deflate "urn:oasis:names:tc:SAML:2.0:bindings:URL-Encoding:DEFLATE"

  def signin(conn, params) do
    integration_id = params["integration_id"]
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
        |> Plug.Conn.put_session("return_to", return_to)
        |> Plug.Conn.put_session("relay_state", relay_state)
        |> Plug.Conn.put_session("integration_id", integration.identifier)
        |> Phoenix.Controller.redirect(external: url)

      {:error, :not_found} ->
        Phoenix.Controller.redirect(conn,
          to:
            Routes.sso_path(conn, :login_form,
              error: "Wrong email.",
              return_to: return_to
            )
        )
    end
  end

  def consume(conn, _params) do
    saml_response = conn.body_params["SAMLResponse"]
    relay_state = conn.body_params["RelayState"] |> safe_decode_www_form()
    return_to = Plug.Conn.get_session(conn, "return_to")
    integration_id = Plug.Conn.get_session(conn, "integration_id")

    with {:ok, integration} <- SSO.get_integration(integration_id),
         :ok <- validate_authresp(conn, integration, relay_state),
         {:ok, {root, assertion}} = SimpleSaml.parse_response(saml_response),
         {:ok, cert} = X509.Certificate.from_pem(integration.config.idp_cert_pem),
         public_key = X509.Certificate.public_key(cert),
         :ok <- SimpleSaml.verify_and_validate_response(root, assertion, public_key),
         {:ok, attributes} <- extract_attributes(root) do
      session_timeout_minutes = integration.team.policy.sso_session_timeout_minutes

      expires_at =
        NaiveDateTime.add(NaiveDateTime.utc_now(:second), session_timeout_minutes, :minute)

      identity =
        %SSO.Identity{
          id: assertion.name_id,
          name: name_from_attributes(attributes),
          email: attributes.email,
          expires_at: expires_at
        }

      PlausibleWeb.UserAuth.log_in_user(conn, identity, return_to)
    else
      {:error, reason} ->
        Phoenix.Controller.redirect(conn,
          to:
            Routes.sso_path(conn, :login_form,
              error: error_by_reason(reason),
              return_to: return_to
            )
        )
    end
  end

  defp error_by_reason(:not_found), do: "Wrong email."
  defp error_by_reason(reason), do: "Authentication failed (reason: #{inspect(reason)})."

  defp name_from_attributes(attributes) do
    [attributes.first_name, attributes.last_name]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
    |> String.trim()
  end

  defp extract_attributes(root_node) do
    with {:ok, assertion_node} <- XmlNode.first_child(root_node, ~r/.*:?Assertion$/),
         {:ok, attributes_node} <-
           XmlNode.first_child(assertion_node, ~r/.*:?AttributeStatement$/),
         {:ok, attribute_nodes} <- XmlNode.children(attributes_node) do
      found = get_attributes(attribute_nodes)

      attributes = %{
        email: found["email"],
        first_name: found["first_name"],
        last_name: found["last_name"]
      }

      cond do
        !attributes.email ->
          {:error, :missing_email_attribute}

        !attributes.first_name && !attributes.last_name ->
          {:error, :missing_name_attributes}

        true ->
          {:ok, attributes}
      end
    end
  end

  defp get_attributes(nodes) do
    Enum.reduce(nodes, %{}, fn node, attributes ->
      with {:ok, name} <- XmlNode.attribute(node, "Name"),
           {:ok, value_node} <- XmlNode.first_child(node, ~r/.*:?AttributeValue$/),
           {:ok, value} <- XmlNode.text(value_node) do
        Map.put(attributes, name, value)
      else
        _ ->
          attributes
      end
    end)
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

  defp validate_authresp(conn, integration, relay_state) do
    rs_in_session = Plug.Conn.get_session(conn, "relay_state")
    idp_id_in_session = Plug.Conn.get_session(conn, "integration_id")
    url_in_session = Plug.Conn.get_session(conn, "return_to")

    cond do
      rs_in_session == nil || rs_in_session != relay_state ->
        {:error, :invalid_relay_state}

      idp_id_in_session == nil || idp_id_in_session != integration.identifier ->
        {:error, :invalid_integration_id}

      url_in_session == nil ->
        {:error, :invalid_return_to}

      true ->
        :ok
    end
  end

  defp gen_id() do
    24 |> :crypto.strong_rand_bytes() |> Base.url_encode64()
  end
end
