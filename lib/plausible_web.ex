defmodule PlausibleWeb do
  def controller do
    quote do
      use Phoenix.Controller, namespace: PlausibleWeb

      import Plug.Conn
      import PlausibleWeb.ControllerHelpers
      alias PlausibleWeb.Router.Helpers, as: Routes
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/plausible_web/templates",
        namespace: PlausibleWeb

      # Import convenience functions from controllers
      import Phoenix.Controller, only: [view_module: 1]

      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML
      use Phoenix.Component

      import PlausibleWeb.ErrorHelpers
      import PlausibleWeb.FormHelpers
      import PlausibleWeb.Components.Generic
      alias PlausibleWeb.Router.Helpers, as: Routes
    end
  end

  def router do
    quote do
      use Phoenix.Router
      import Plug.Conn
      import Phoenix.Controller
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def plugins_api_controller do
    quote do
      use Phoenix.Controller, namespace: PlausibleWeb.Plugins.API
      import Plug.Conn
      import PlausibleWeb.Plugins.API.Router.Helpers
      import PlausibleWeb.Plugins.API, only: [base_uri: 0]

      alias PlausibleWeb.Plugins.API.Schemas
      alias PlausibleWeb.Plugins.API.Views
      alias PlausibleWeb.Plugins.API.Context

      plug(OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true)

      use OpenApiSpex.ControllerSpecs
    end
  end

  def plugins_api_view do
    quote do
      use Phoenix.View,
        namespace: PlausibleWeb.Plugins.API,
        root: ""

      alias PlausibleWeb.Plugins.API.Router.Helpers
      import PlausibleWeb.Plugins.API.Views.Pagination, only: [render_metadata_links: 4]
    end
  end

  def open_api_schema do
    quote do
      require OpenApiSpex
      alias OpenApiSpex.Schema
      alias PlausibleWeb.Plugins.API.Schemas
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
