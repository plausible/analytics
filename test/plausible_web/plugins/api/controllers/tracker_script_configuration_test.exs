defmodule PlausibleWeb.Plugins.API.Controllers.TrackerScriptConfigurationTest do
  use PlausibleWeb.PluginsAPICase, async: true
  use Plausible.Teams.Test
  import Plausible.AssertMatches
  alias PlausibleWeb.Plugins.API.Schemas

  describe "examples" do
    test "TrackerScriptConfiguration" do
      assert_schema(
        Schemas.TrackerScriptConfiguration.schema().example,
        "TrackerScriptConfiguration",
        spec()
      )
    end

    test "TrackerScriptConfiguration.UpdateRequest" do
      assert_schema(
        Schemas.TrackerScriptConfiguration.UpdateRequest.schema().example,
        "TrackerScriptConfiguration.UpdateRequest",
        spec()
      )
    end
  end

  describe "unauthorized calls" do
    for {method, url} <- [
          {:get,
           Routes.plugins_api_tracker_script_configuration_url(PlausibleWeb.Endpoint, :get)},
          {:put,
           Routes.plugins_api_tracker_script_configuration_url(
             PlausibleWeb.Endpoint,
             :update,
             %{}
           )}
        ] do
      test "unauthorized call: #{method} #{url}", %{conn: conn} do
        conn
        |> unquote(method)(unquote(url))
        |> json_response(401)
        |> assert_schema("UnauthorizedError", spec())
      end
    end
  end

  describe "get/put /tracker_script_configuration" do
    test "inserts a new tracker script configuration if one doesn't exist and returns it consistently",
         %{conn: conn, token: token, site: site} do
      initial_resp = get_tracker_script_configuration(conn, site, token)

      id = initial_resp.tracker_script_configuration.id

      assert_matches ^strict_map(%{
                       id: ^any(:string),
                       installation_type: "manual",
                       track_404_pages: false,
                       hash_based_routing: false,
                       outbound_links: false,
                       file_downloads: false,
                       form_submissions: false
                     }) = initial_resp.tracker_script_configuration

      resp = get_tracker_script_configuration(conn, site, token)

      assert_matches ^strict_map(%{
                       id: ^id,
                       installation_type: "manual",
                       track_404_pages: false,
                       hash_based_routing: false,
                       outbound_links: false,
                       file_downloads: false,
                       form_submissions: false
                     }) = resp.tracker_script_configuration
    end

    test "both return updated tracker script configuration", %{
      conn: conn,
      token: token,
      site: site
    } do
      update_response =
        update_tracker_script_configuration(conn, site, token, %{
          tracker_script_configuration: %{
            installation_type: "manual",
            track_404_pages: true,
            file_downloads: true
          }
        })

      get_response = get_tracker_script_configuration(conn, site, token)

      assert get_response == update_response

      assert_matches ^strict_map(%{
                       id: ^update_response.tracker_script_configuration.id,
                       installation_type: "manual",
                       track_404_pages: true,
                       hash_based_routing: false,
                       outbound_links: false,
                       file_downloads: true,
                       form_submissions: false
                     }) = get_response.tracker_script_configuration
    end

    test "multiple updates only overwrite the specified fields", %{
      conn: conn,
      token: token,
      site: site
    } do
      update_tracker_script_configuration(conn, site, token, %{
        tracker_script_configuration: %{
          installation_type: "manual",
          track_404_pages: true,
          hash_based_routing: true,
          outbound_links: true,
          file_downloads: true,
          form_submissions: true
        }
      })

      update_response =
        update_tracker_script_configuration(conn, site, token, %{
          tracker_script_configuration: %{
            installation_type: "wordpress",
            track_404_pages: false
          }
        })

      assert_matches ^strict_map(%{
                       id: ^any(:string),
                       installation_type: "wordpress",
                       track_404_pages: false,
                       hash_based_routing: true,
                       outbound_links: true,
                       file_downloads: true,
                       form_submissions: true
                     }) = update_response.tracker_script_configuration
    end

    test "ignores unknown fields", %{conn: conn, token: token, site: site} do
      response =
        update_tracker_script_configuration(conn, site, token, %{
          tracker_script_configuration: %{
            installation_type: "wordpress",
            hash_based_routing: true,
            unknown_field: "unknown_value"
          }
        })

      assert_matches ^strict_map(%{
                       id: ^any(:string),
                       installation_type: "wordpress",
                       track_404_pages: false,
                       hash_based_routing: true,
                       outbound_links: false,
                       file_downloads: false,
                       form_submissions: false
                     }) = response.tracker_script_configuration
    end

    test "installation_type parameter is required", %{conn: conn, token: token, site: site} do
      url = Routes.plugins_api_tracker_script_configuration_url(PlausibleWeb.Endpoint, :update)

      payload = %{tracker_script_configuration: %{hash_based_routing: true}}

      response =
        conn
        |> authenticate(site.domain, token)
        |> put_req_header("content-type", "application/json")
        |> put(url, payload)
        |> json_response(422)
        |> assert_schema("UnprocessableEntityError", spec())

      assert %{errors: [%{detail: "Missing field: installation_type"}]} = response
    end

    test "installation_type and boolean parameters are validated", %{
      conn: conn,
      token: token,
      site: site
    } do
      url = Routes.plugins_api_tracker_script_configuration_url(PlausibleWeb.Endpoint, :update)

      payload = %{
        tracker_script_configuration: %{installation_type: "unknown", hash_based_routing: "1234"}
      }

      response =
        conn
        |> authenticate(site.domain, token)
        |> put_req_header("content-type", "application/json")
        |> put(url, payload)
        |> json_response(422)
        |> assert_schema("UnprocessableEntityError", spec())

      assert %{
               errors: [
                 %{detail: "Invalid value for enum"},
                 %{detail: "Invalid boolean. Got: string"}
               ]
             } = response
    end
  end

  defp get_tracker_script_configuration(conn, site, token) do
    url = Routes.plugins_api_tracker_script_configuration_url(PlausibleWeb.Endpoint, :get)

    conn
    |> authenticate(site.domain, token)
    |> get(url)
    |> json_response(200)
    |> assert_schema("TrackerScriptConfiguration", spec())
  end

  defp update_tracker_script_configuration(conn, site, token, payload) do
    url = Routes.plugins_api_tracker_script_configuration_url(PlausibleWeb.Endpoint, :update)

    conn
    |> authenticate(site.domain, token)
    |> put_req_header("content-type", "application/json")
    |> put(url, payload)
    |> json_response(200)
    |> assert_schema("TrackerScriptConfiguration", spec())
  end
end
