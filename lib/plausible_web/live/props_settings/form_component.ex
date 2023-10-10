defmodule PlausibleWeb.Live.PropsSettings.FormComponent do
  @moduledoc """
  Live component for the custom props creation form
  """
  use PlausibleWeb, :live_component
  import PlausibleWeb.Live.Components.Form
  alias PlausibleWeb.Live.Components.ComboBox

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form :let={f} for={@form} phx-target={@myself} phx-submit="allow-prop">
        <div class="py-2">
          <.label for="prop_input">
            Property
          </.label>

          <.live_component
            id="prop_input"
            submit_name="prop"
            class="mt-2"
            module={ComboBox}
            on_select={&send_update(@myself, selection: &1)}
            suggest_fun={
              fn
                "", [] ->
                  options =
                    @site
                    |> Plausible.Props.suggest_keys_to_allow()
                    |> Enum.map(&{&1, &1})

                  # Use of @myself here required LiveView upgrade https://github.com/phoenixframework/phoenix_live_view/blob/v0.20.1/CHANGELOG.md#enhancements-1
                  send_update(@myself, prop_key_options_count: Enum.count(options))

                  options

                input, options ->
                  ComboBox.StaticSearch.suggest(input, options)
              end
            }
            creatable
          />

          <.error :for={{msg, opts} <- f[:allowed_event_props].errors}>
            <%= Enum.reduce(opts, msg, fn {key, value}, acc ->
              String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
            end) %>
          </.error>
        </div>

        <div class="mt-5 sm:mt-6">
          <.button
            phx-disable-with="Saving..."
            type="submit"
            class="group w-full inline-flex justify-center custom-class phx-submit-loading:animate-pulse"
          >
            <Heroicons.arrow_right_circle class="group-[.custom-class]:animate-spin h-4 w-4" />
            Add Property →
          </.button>
        </div>

        <button
          :if={@prop_key_options_count > 0}
          title="Use this to add any existing properties from your past events into your settings. This allows you to set up properties without having to manually enter each item."
          class="mt-2 text-sm hover:underline text-indigo-600 dark:text-indigo-400 text-left"
          phx-click="allow-existing-props"
        >
          Already sending custom properties? Click to add <%= @prop_key_options_count %> existing properties we found.
        </button>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{site: site}, socket) do
    changeset = Plausible.Props.allow_changeset(site, [])

    {:ok,
     socket
     |> assign(site: site, form: to_form(changeset))
     |> assign_new(:prop_key_options_count, fn -> 0 end)}
  end

  def update(%{prop_key_options_count: _count} = assigns, socket) do
    {:ok, socket |> assign(assigns)}
  end

  def update(%{selection: _selection}, socket) do
    # noop
    {:ok, socket}
  end

  @impl true
  def handle_event("allow-prop", %{"prop" => prop}, socket) do
    case Plausible.Props.allow(socket.assigns.site, prop) do
      {:ok, _site} ->
        send(self(), {__MODULE__, {:prop_allowed, prop}})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply,
         assign(socket,
           form: to_form(Map.put(changeset, :action, :validate))
         )}
    end
  end
end
