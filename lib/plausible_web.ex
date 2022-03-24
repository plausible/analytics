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
      import Phoenix.Controller, only: [get_flash: 1, get_flash: 2, view_module: 1]

      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML

      import PlausibleWeb.ErrorHelpers
      import PlausibleWeb.FormHelpers
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

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
