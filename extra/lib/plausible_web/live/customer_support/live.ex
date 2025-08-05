defmodule PlausibleWeb.CustomerSupport.Live do
  @moduledoc """
  Shared module providing common LiveView functionality for Customer Support.

  Provides:
  - Standard mount/3 and handle_info/2 implementations
  - Tab navigation components and routing utilities  
  - Common aliases and imports for Customer Support LiveViews
  """

  defmacro __using__(_opts) do
    quote do
      use PlausibleWeb, :live_view

      alias Plausible.CustomerSupport.Resource
      alias PlausibleWeb.CustomerSupport.Components.Layout
      import PlausibleWeb.CustomerSupport.Live
      import PlausibleWeb.Components.Generic
      alias PlausibleWeb.Router.Helpers, as: Routes

      def mount(_params, _session, socket) do
        {:ok, socket}
      end

      def handle_info({:success, msg}, socket) do
        {:noreply, put_flash(socket, :success, msg)}
      end

      def handle_info({:error, msg}, socket) do
        {:noreply, put_flash(socket, :error, msg)}
      end

      def handle_info({:navigate, path, success_msg}, socket) do
        socket = if success_msg, do: put_flash(socket, :success, success_msg), else: socket
        {:noreply, push_navigate(socket, to: path)}
      end

      def handle_params(%{"id" => _id} = params, _uri, socket) do
        handle_params(Map.put(params, "tab", "overview"), nil, socket)
      end

      defoverridable mount: 3, handle_info: 2, handle_params: 3
    end
  end

  use Phoenix.Component
  import Phoenix.LiveView

  attr :to, :string, required: true
  attr :tab, :string, required: true
  slot :inner_block, required: true

  def tab(assigns) do
    current_class = "text-gray-900 dark:text-gray-100"

    inactive_class =
      "text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"

    assigns =
      assign(
        assigns,
        :link_class,
        if(assigns.to == assigns.tab, do: current_class, else: inactive_class)
      )

    ~H"""
    <.link
      patch={"?tab=#{@to}"}
      class={[
        @link_class,
        "group relative min-w-0 flex-1 overflow-hidden bg-white dark:bg-gray-800 py-4 px-6 text-center text-sm font-medium hover:bg-gray-50 dark:hover:bg-gray-750 focus:z-10 first:rounded-l-lg last:rounded-r-lg"
      ]}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  attr :tab, :string, required: true
  attr :extra_classes, :string, default: ""
  slot :tabs, required: true

  def tab_navigation(assigns) do
    ~H"""
    <div class="mt-4">
      <div class="hidden sm:block">
        <nav
          class={[
            "isolate flex divide-x dark:divide-gray-900 divide-gray-200 rounded-lg shadow dark:shadow-1",
            @extra_classes
          ]}
          aria-label="Tabs"
        >
          {render_slot(@tabs)}
        </nav>
      </div>
    </div>
    """
  end

  def go_to_tab(socket, tab, params, resource_key, component) do
    tab_params = Map.drop(params, ["id", "tab"])
    resource = Map.get(socket.assigns, resource_key)

    update_params = [
      id: "#{resource_key}-#{resource.id}-#{tab}",
      tab: tab,
      tab_params: tab_params
    ]

    update_params = Keyword.put(update_params, resource_key, resource)

    send_update(component, update_params)

    socket
  end
end
