defmodule PlausibleWeb.Plugins.API.Spec do
  @moduledoc """
  OpenAPI specification for the Plugins API
  """
  alias OpenApiSpex.{Components, Info, OpenApi, Paths, Server}
  alias PlausibleWeb.Router
  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      servers: [
        %Server{
          description: "This server",
          url: PlausibleWeb.Endpoint.url(),
          variables: %{}
        }
      ],
      info: %Info{
        title: "Plausible Plugins API",
        version: "1.0-rc"
      },
      # Populate the paths from a phoenix router
      paths: Paths.from_router(Router),
      components: %Components{
        securitySchemes: %{
          "basic_auth" => %OpenApiSpex.SecurityScheme{
            type: "http",
            scheme: "basic",
            description: """
            HTTP basic access authentication using your Site Domain as the
            username and the Plugin Token contents as the password.
            Note that Site Domain is optional, a password alone suffices.

            For more information see
            https://en.wikipedia.org/wiki/Basic_access_authentication
            """
          }
        }
      },
      security: [%{"basic_auth" => []}]
    }
    # Discover request/response schemas from path specs
    |> OpenApiSpex.resolve_schema_modules()
  end
end
