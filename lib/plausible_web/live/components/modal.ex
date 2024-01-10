defmodule PlausibleWeb.Live.Components.Modal do
  @moduledoc """
  LiveView implementation of modal component.

  This component is a general purpose modal implementation for LiveView
  with emphasis on keeping nested components largely agnostic of the fact
  that they are placed in a modal and maintaining good user experience
  on connections with high latency.

  ## Usage

  An example use case for a modal is embedding a form inside
  existing live view which allows adding new entries of some kind:

  ```
  <.live_component module={Modal} id="some-form-modal">
    <.live_component
      module={SomeForm}
      id="some-form"
      on_save_form={
        fn entry, socket ->
          send(self(), {:entry_added, entry})
          Modal.close(socket, "some-form-modal")
        end
      }
    />
  </.live_component>
  ```

  Then somewhere in the same live view the modal is rendered in:

  ```
  <.button x-data x-on:click={Modal.JS.open("goals-form-modal")}>
    + Add Entry
  </.button>
  ```

  ## Explanation

  The component embedded inside the modal is always rendered when
  the live view is mounted but is kept hidden until `Modal.JS.open`
  is called on it. On subsequent openings within the same session
  the contents of the modal are completely remounted. This assures
  that any stateful components inside the modal are reset to their
  initial state.

  `Modal` exposes two functions for managing window state:

    * `Modal.JS.open/1` - to open the modal from the frontend. It's
      important to make sure the element triggering that call is
      wrapped in an Alpine UI component - or is an Alpine component
      itself - adding `x-data` attribute without any value is enough
      to ensure that.
    * `Modal.close/2` - to close the modal from the backend; usually
      done inside wrapped component's `handle_event/2`. The example
      qouted above shows one way to implement this, under that assumption
      that the component exposes a callback, like this:

      ```
      defmodule SomeForm do
        use Phoenix.LiveComponent

        def update(assigns, socket) do
          # ...

          {:ok, assign(socket, :on_save_form, assigns.on_save_form)}
        end

        #...

        def handle_event("save-form", %{"form" => form}, socket) do
          case save_entry(form) do
            {:ok, entry} ->
              {:noreply, socket.assigns.on_save_form(entry, socket)}

            # error case handling ...
          end
        end
      end
      ```

      Using callback approach has an added benefit of making the
      component more flexible.

  """

  use Phoenix.LiveComponent, global_prefixes: ~w(x-)

  alias Phoenix.LiveView

  defmodule JS do
    @moduledoc false

    @spec open(String.t()) :: String.t()
    def open(id) do
      "$dispatch('open-modal', '#{id}')"
    end
  end

  @spec close(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def close(socket, id) do
    Phoenix.LiveView.push_event(socket, "close-modal", %{id: id})
  end

  @impl true
  def update(assigns, socket) do
    socket =
      assign(socket,
        id: assigns.id,
        inner_block: assigns.inner_block,
        load_content?: true
      )

    {:ok, socket}
  end

  attr :id, :any, required: true
  attr :class, :string, default: ""
  slot :inner_block, required: true

  def render(assigns) do
    class = [
      "md:w-1/2 w-full max-w-md mx-auto bg-white dark:bg-gray-800 shadow-md rounded px-8 pt-6 pb-8 mb-4 mt-8",
      assigns.class
    ]

    assigns =
      assign(assigns,
        modal_class: ["modal-dialog relative" | class],
        modal_loading_class: ["modal-loading hidden" | class]
      )

    ~H"""
    <div
      id={@id}
      class="[&[data-phx-ref]_div.modal-dialog]:hidden [&[data-phx-ref]_div.modal-loading]:block"
      data-modal
      x-cloak
      x-data="{
        firstLoadDone: false,
        modalOpen: false,
        openModal() {
          if (this.firstLoadDone) {
            liveSocket.execJS($el, $el.dataset.onclose);
            liveSocket.execJS($el, $el.dataset.onopen);
          } else {
            this.firstLoadDone = true;
          }

          this.modalOpen = true;
        },
        closeModal() {
          this.modalOpen = false;
        }
      }"
      x-on:open-modal.window={"if ($event.detail === '#{@id}') openModal()"}
      x-on:close-modal.window={"if ($event.detail === '#{@id}') closeModal()"}
      data-onopen={LiveView.JS.push("open", target: @myself)}
      data-onclose={LiveView.JS.push("close", target: @myself)}
      x-on:keydown.escape.window="closeModal()"
    >
      <div x-show="modalOpen" class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity z-50">
      </div>
      <div
        x-show="modalOpen"
        class="fixed inset-0 items-top justify-center mt-16 z-50 overflow-y-auto overflow-x-hidden"
      >
        <div :if={@load_content?} class={@modal_class} x-on:click.outside="closeModal()">
          <%= render_slot(@inner_block) %>
        </div>
        <div class={@modal_loading_class}>
          <div class="text-center">
            <PlausibleWeb.Components.Generic.spinner class="inline-block" /> Loading...
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("open", _, socket) do
    {:noreply, assign(socket, load_content?: true)}
  end

  def handle_event("close", _, socket) do
    {:noreply, assign(socket, load_content?: false)}
  end
end
