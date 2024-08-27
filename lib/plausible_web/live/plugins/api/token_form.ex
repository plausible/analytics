defmodule PlausibleWeb.Live.Plugins.API.TokenForm do
  @moduledoc """
  Live view for the goal creation form
  """
  use PlausibleWeb, live_view: :no_sentry_context
  import PlausibleWeb.Live.Components.Form

  alias Plausible.Sites
  alias Plausible.Plugins.API.{Token, Tokens}

  def mount(
        _params,
        %{
          "token_description" => token_description,
          "domain" => domain,
          "rendered_by" => pid
        },
        socket
      ) do
    socket =
      socket
      |> assign_new(:site, fn %{current_user: current_user} ->
        Sites.get_for_user!(current_user, domain, [:owner, :admin, :super_admin])
      end)

    token = Token.generate()
    form = to_form(Token.insert_changeset(socket.assigns.site, token))

    {:ok,
     assign(socket,
       token_description: token_description,
       token: token,
       form: form,
       domain: domain,
       rendered_by: pid,
       tabs: %{custom_events: true, pageviews: false}
     )}
  end

  def render(assigns) do
    ~H"""
    <div
      class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity z-50"
      phx-window-keydown="cancel-add-token"
      phx-key="Escape"
    >
    </div>
    <div class="fixed inset-0 flex items-center justify-center mt-16 z-50 overflow-y-auto overflow-x-hidden">
      <div class="w-1/2 h-full">
        <.form
          :let={f}
          for={@form}
          class="max-w-md w-full mx-auto bg-white dark:bg-gray-800 shadow-md rounded px-8 pt-6 pb-8 mb-4 mt-8"
          phx-submit="save-token"
          phx-click-away="cancel-add-token"
        >
          <h2 class="text-xl font-black dark:text-gray-100 mb-8">
            Add Plugin Token for <%= @domain %>
          </h2>

          <.input
            autofocus
            field={f[:description]}
            label="Description"
            class="focus:ring-indigo-500 focus:border-indigo-500 dark:bg-gray-900 dark:text-gray-300 block w-7/12 rounded-md sm:text-sm border-gray-300 dark:border-gray-500 w-full p-2 mt-2"
            placeholder="e.g. Signup"
            value={@token_description}
            autocomplete="off"
          />

          <.input_with_clipboard
            id="token-clipboard"
            name="token_clipboard"
            label="Plugin Token"
            value={@token.raw}
            onfocus="this.value = this.value;"
            class="focus:ring-indigo-500 focus:border-indigo-500 bg-gray-50 dark:bg-gray-850 dark:text-gray-300 block w-7/12 rounded-md sm:text-sm border-gray-300 dark:border-gray-500 w-full p-2 mt-2"
          />

          <p class="text-sm mt-2 text-gray-500 dark:text-gray-200">
            Once created, we will not be able to show the Plugin Token again.
            Please copy the Plugin Token now and store it in a secure place.
            <span :if={@token_description == "WordPress"}>
              You'll need to paste it in the settings area of the Plausible WordPress plugin.
            </span>
          </p>
          <div class="py-4 mt-8">
            <PlausibleWeb.Components.Generic.button type="submit" class="w-full">
              Add Plugin Token →
            </PlausibleWeb.Components.Generic.button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  def handle_event("save-token", %{"token" => %{"description" => description}}, socket) do
    case Tokens.create(socket.assigns.site, description, socket.assigns.token) do
      {:ok, token, _} ->
        send(socket.assigns.rendered_by, {:token_added, token})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("cancel-add-token", _value, socket) do
    send(socket.assigns.rendered_by, :cancel_add_token)
    {:noreply, socket}
  end
end
