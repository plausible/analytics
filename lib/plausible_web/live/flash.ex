defmodule PlausibleWeb.Live.Flash do
  @moduledoc """
  Flash component for LiveViews - works also when embedded within dead views
  """

  use Phoenix.Component
  alias Phoenix.LiveView.JS
  alias Phoenix.Flash

  @flash_timer_assigns %{
    success: :clear_flash_success,
    error: :clear_flash_error
  }

  @flash_timer_timeout_ms 5000

  defmacro __using__(_opts) do
    quote do
      import PlausibleWeb.Live.Flash, only: [put_live_flash: 3, flash_messages: 1]

      def handle_info({:clear_live_flash, key}, socket) do
        {:noreply, Phoenix.LiveView.clear_flash(socket, key)}
      end
    end
  end

  def put_live_flash(socket, key, message) when key in [:success, :error] do
    timer_key = Map.fetch!(@flash_timer_assigns, key)

    if flash_timer = socket.assigns[timer_key] do
      Process.cancel_timer(flash_timer)
    end

    flash_timer =
      Process.send_after(
        self(),
        {:clear_live_flash, key},
        @flash_timer_timeout_ms
      )

    socket
    |> Phoenix.LiveView.put_flash(key, message)
    |> assign(timer_key, flash_timer)
  end

  def flash_messages(assigns) do
    ~H"""
    <div>
      <div
        :if={@flash != %{} or Application.get_env(:plausible, :environment) == "dev"}
        class="inset-0 z-50 fixed flex flex-col-reverse items-center sm:items-end justify-start sm:justify-end px-4 py-6 pointer-events-none sm:p-6"
      >
        <.flash :if={Flash.get(@flash, :success)} key="success">
          <:icon>
            <.icon_success />
          </:icon>
          <:title>
            {Flash.get(@flash, :success_title) || "Success!"}
          </:title>
          <:message>
            {Flash.get(@flash, :success)}
          </:message>
        </.flash>
        <.flash :if={Flash.get(@flash, :error)} key="error">
          <:icon>
            <.icon_error />
          </:icon>
          <:title>
            {Flash.get(@flash, :error_title) || "Error!"}
          </:title>
          <:message>
            {Flash.get(@flash, :error)}
          </:message>
        </.flash>
        <.flash
          :if={Application.get_env(:plausible, :environment) == "dev"}
          id="live-view-connection-status"
          class="hidden"
          phx-disconnected={JS.show()}
          phx-connected={JS.hide()}
          on_close={JS.hide()}
        >
          <:icon>
            <.icon_error />
          </:icon>
          <:title>
            Oops, a server blip
          </:title>
          <:message>
            Live socket disconnected.
          </:message>
        </.flash>
      </div>
    </div>
    """
  end

  slot(:icon, required: true)
  slot(:title, required: true)
  slot(:message, required: true)
  attr(:key, :string, default: nil)
  attr(:on_close, :any, default: "lv:clear-flash")
  attr(:class, :string, default: "")
  attr(:rest, :global)

  def flash(assigns) do
    ~H"""
    <div
      class={[
        @class,
        "mb-4 max-w-sm w-full bg-white dark:bg-gray-800 shadow-lg rounded-lg pointer-events-auto"
      ]}
      {@rest}
    >
      <div class="rounded-lg ring-1 ring-black ring-opacity-5 overflow-hidden">
        <div class="p-4">
          <div class="flex items-start">
            {render_slot(@icon)}
            <div class="ml-3 w-0 flex-1 pt-0.5">
              <p class="text-sm leading-5 font-medium text-gray-900 dark:text-gray-100">
                {render_slot(@title)}
              </p>
              <p class="mt-1 text-sm leading-5 text-gray-500 dark:text-gray-200">
                {render_slot(@message)}
              </p>
            </div>
            <div class="ml-4 flex-shrink-0 flex">
              <.clear_flash_button on_close={@on_close} key={@key} />
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def icon_success(assigns) do
    ~H"""
    <div class="flex-shrink-0">
      <svg
        class="h-6 w-6 text-green-400"
        xmlns="http://www.w3.org/2000/svg"
        fill="none"
        viewBox="0 0 24 24"
        stroke="currentColor"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="2"
          d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
        />
      </svg>
    </div>
    """
  end

  def icon_error(assigns) do
    ~H"""
    <svg
      class="w-6 h-6 text-red-400"
      fill="none"
      stroke="currentColor"
      viewBox="0 0 24 24"
      xmlns="http://www.w3.org/2000/svg"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
      >
      </path>
    </svg>
    """
  end

  def clear_flash_button(assigns) do
    ~H"""
    <button
      class="inline-flex text-gray-400 focus:outline-none focus:text-gray-500 dark:focus:text-gray-200 transition ease-in-out duration-150"
      phx-click={@on_close}
      phx-value-key={@key}
    >
      <svg class="h-5 w-5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
        <path
          fill-rule="evenodd"
          d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z"
          clip-rule="evenodd"
        />
      </svg>
    </button>
    """
  end
end
