defmodule PlausibleWeb do
  use Plausible

  def live_view(opts \\ []) do
    quote do
      use Plausible
      use Phoenix.LiveView, global_prefixes: ~w(x-)
      use PlausibleWeb.Live.Flash

      use PlausibleWeb.Live.AuthContext

      unless :no_sentry_context in unquote(opts) do
        use PlausibleWeb.Live.SentryContext
      end

      alias PlausibleWeb.Router.Helpers, as: Routes
      alias PlausibleWeb.InternalRouter.Helpers, as: InternalRoutes
      alias Phoenix.LiveView.JS

      import PlausibleWeb.Components.Generic
      import PlausibleWeb.Live.Components.Form
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent, global_prefixes: ~w(x-)
      import PlausibleWeb.Components.Generic
      import PlausibleWeb.Live.Components.Form
      alias Phoenix.LiveView.JS
      alias PlausibleWeb.Router.Helpers, as: Routes
      alias PlausibleWeb.InternalRouter.Helpers, as: InternalRoutes
    end
  end

  def component do
    quote do
      use Phoenix.Component, global_prefixes: ~w(x-)
      import PlausibleWeb.Components.Generic
      import PlausibleWeb.Live.Components.Form
      alias Phoenix.LiveView.JS
      alias PlausibleWeb.Router.Helpers, as: Routes
      alias PlausibleWeb.InternalRouter.Helpers, as: InternalRoutes
    end
  end

  def controller do
    quote do
      use Phoenix.Controller, namespace: PlausibleWeb

      import Plug.Conn
      import PlausibleWeb.ControllerHelpers
      alias PlausibleWeb.Router.Helpers, as: Routes
      alias PlausibleWeb.InternalRouter.Helpers, as: InternalRoutes
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/plausible_web/templates",
        namespace: PlausibleWeb

      # Import convenience functions from controllers
      import Phoenix.Controller, only: [view_module: 1]

      use Phoenix.Component

      import PlausibleWeb.Components.Generic
      import PlausibleWeb.Live.Components.Form
      alias PlausibleWeb.Router.Helpers, as: Routes
      alias PlausibleWeb.InternalRouter.Helpers, as: InternalRoutes
    end
  end

  on_ee do
    def extra_view do
      quote do
        use Phoenix.View,
          root: "extra/lib/plausible_web/templates",
          namespace: PlausibleWeb

        # Import convenience functions from controllers
        import Phoenix.Controller, only: [view_module: 1]

        use Phoenix.Component

        import PlausibleWeb.Components.Generic
        import PlausibleWeb.Live.Components.Form
        alias PlausibleWeb.Router.Helpers, as: Routes
      end
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
      import PlausibleWeb.Router.Helpers

      alias PlausibleWeb.Plugins.API.Schemas
      alias PlausibleWeb.Plugins.API.Views
      alias PlausibleWeb.Plugins.API.Errors
      alias Plausible.Plugins.API

      plug(OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true, replace_params: false)

      use OpenApiSpex.ControllerSpecs
    end
  end

  def plugins_api_view do
    quote do
      use Phoenix.View,
        namespace: PlausibleWeb.Plugins.API,
        root: ""

      alias PlausibleWeb.Router.Helpers
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

  defmacro __using__([{which, opts}]) when is_atom(which) do
    apply(__MODULE__, which, [List.wrap(opts)])
  end
end
