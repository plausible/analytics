defmodule PlausibleWeb.Plugins.API.Router do
  use PlausibleWeb, :router

  pipeline :auth do
    plug(PlausibleWeb.Plugs.AuthorizePluginsAPI)
  end

  pipeline :api do
    plug(:accepts, ["json"])
    plug(OpenApiSpex.Plug.PutApiSpec, module: PlausibleWeb.Plugins.API.Spec)
  end

  scope "/spec" do
    pipe_through(:api)
    get("/openapi", OpenApiSpex.Plug.RenderSpec, [])
    get("/swagger-ui", OpenApiSpex.Plug.SwaggerUI, path: "/api/plugins/spec/openapi")
  end

  scope "/v1", PlausibleWeb.Plugins.API.Controllers do
    pipe_through([:api, :auth])

    get("/shared_links", SharedLinks, :index)
    get("/shared_links/:id", SharedLinks, :get)
    post("/shared_links", SharedLinks, :create)
  end
end
