defmodule PlausibleWeb.Live.Components.Modal do
  @moduledoc ~S"""
  LiveView implementation of modal component.

  This component is a general purpose modal implementation for LiveView
  with emphasis on keeping nested components largely agnostic of the fact
  that they are placed in a modal and maintaining good user experience
  on connections with high latency.

  ## Usage

  An example use case for a modal is embedding a form inside
  existing live view which allows adding new entries of some kind:

  ```
  <.live_component module={Modal} id="some-form-modal" :let={modal_unique_id}>
    <.live_component
      module={SomeForm}
      id={"some-form-#{modal_unique_id}"}
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
  initial state. The modal component provides `modal_unique_id`
  as an argument to its inner block. Appending this ID to every
  live components' ID nested inside the modal is important for
  consistent state reset on every reopening. This also applies
  to live components nested inside live components embedded directly
  in the modal's inner block - then the unique ID should be also
  passed down as an attribute and appended accordingly. Appending can
  be skipped if embedded component handles state reset explicitly
  (via, for instance, `phx-click-away` callback).

  `Modal` exposes a number of functions for managing window state:

    * `Modal.JS.preopen/1` - to preopen the modal on the frontend.
      Useful when the actual opening is done server-side with
      `Modal.open/2` - helps avoid lack of feedback to the end user
      when server-side state change before opening the modal is
      still in progress.
    * `Modal.JS.open/1` - to open the modal from the frontend. It's
      important to make sure the element triggering that call is
      wrapped in an Alpine UI component - or is an Alpine component
      itself - adding `x-data` attribute without any value is enough
      to ensure that.
    * `Modal.open/2` - to open the modal from the backend; usually
      called from `handle_event/2` of component wrapping the modal
      and providing the state. Should be used together with
      `Modal.JS.preopen/1` for optimal user experience.
    * `Modal.close/2` - to close the modal from the backend; usually
      done inside wrapped component's `handle_event/2`. The example
      quoted above shows one way to implement this, under that assumption
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

  use PlausibleWeb, :live_component

  alias Phoenix.LiveView

  defmodule JS do
    @moduledoc false

    @spec open(String.t()) :: String.t()
    def open(id) do
      "$dispatch('open-modal', '#{id}')"
    end

    @spec preopen(String.t()) :: String.t()
    def preopen(id) do
      "$dispatch('preopen-modal', '#{id}')"
    end
  end

  @spec open(LiveView.Socket.t(), String.t()) :: LiveView.Socket.t()
  def open(socket, id) do
    LiveView.push_event(socket, "open-modal", %{id: id})
  end

  @spec close(LiveView.Socket.t(), String.t()) :: LiveView.Socket.t()
  def close(socket, id) do
    LiveView.push_event(socket, "close-modal", %{id: id})
  end

  @impl true
  def update(assigns, socket) do
    preload? =
      if Mix.env() in [:test, :ce_test] do
        true
      else
        Map.get(assigns, :preload?, true)
      end

    socket =
      assign(socket,
        id: assigns.id,
        inner_block: assigns.inner_block,
        # Initial value is constant, as dead view ID
        # must match the ID after the connection is
        # established. Otherwise, there will be problems
        # with live components relying on ID for setup
        # on mount (using AlpineJS, for instance).
        load_content?: preload?,
        preload?: preload?,
        modal_sequence_id: 0
      )

    {:ok, socket}
  end

  attr :id, :any, required: true
  attr :class, :string, default: ""
  attr :preload?, :boolean, default: true
  slot :inner_block, required: true

  def render(assigns) do
    class = [
      "md:w-1/2 w-full max-w-md mx-auto bg-white dark:bg-gray-800 shadow-xl rounded-lg px-8 pt-6 pb-8 top-24",
      assigns.class
    ]

    assigns =
      assign(assigns,
        class: ["modal-dialog relative opacity-0 translate-y-4 sm:translate-y-0" | class],
        dialog_id: assigns.id <> "-dialog"
      )

    ~H"""
    <div
      id={@id}
      class="relative z-[2049] [&[data-phx-ref]_div.modal-dialog]:hidden [&[data-phx-ref]_div.modal-loading]:block"
      data-modal
      x-cloak
      x-data="{
        firstLoadDone: false,
        modalOpen: false,
        modalPreopen: false,
        preopenModal() {
          document.body.style['overflow-y'] = 'hidden';

          this.modalPreopen = true;
        },
        openModal() {
          document.body.style['overflow-y'] = 'hidden';

          if (this.firstLoadDone) {
            liveSocket.execJS($el, $el.dataset.onopen);
          } else {
            this.firstLoadDone = true;
          }

          this.modalPreopen = false;
          this.modalOpen = true;
        },
        closeModal() {
          this.modalPreopen = false;
          this.modalOpen = false;
          liveSocket.execJS($el, $el.dataset.onclose);

          setTimeout(function() {
            document.body.style['overflow-y'] = 'auto';
          }, 200);
        }
      }"
      x-init={"firstLoadDone = #{not @preload?}"}
      x-on:preopen-modal.window={"if ($event.detail === '#{@id}') preopenModal()"}
      x-on:open-modal.window={"if ($event.detail === '#{@id}') openModal()"}
      x-on:close-modal.window={"if ($event.detail === '#{@id}') closeModal()"}
      data-onopen={LiveView.JS.push("open", target: @myself)}
      data-onclose={LiveView.JS.push("close", target: @myself)}
      x-on:keydown.escape.window="closeModal()"
      role="dialog"
      aria-modal="true"
    >
      <div
        x-show="modalOpen || modalPreopen"
        x-transition:enter="transition ease-out duration-300"
        x-transition:enter-start="bg-opacity-0"
        x-transition:enter-end="bg-opacity-75"
        x-transition:leave="transition ease-in duration-200"
        x-transition:leave-start="bg-opacity-75"
        x-transition:leave-end="bg-opacity-0"
        class="fixed inset-0 bg-gray-500 bg-opacity-75 z-[2050]"
      >
      </div>
      <div
        x-show="modalPreopen"
        class="fixed flex inset-0 items-start z-[2050] overflow-y-auto overflow-x-hidden"
      >
        <div class="modal-pre-loading w-full self-center">
          <div class="text-center">
            <.spinner class="inline-block h-8 w-8" />
          </div>
        </div>
      </div>
      <div
        x-show="modalOpen"
        class="fixed flex inset-0 items-start z-[2050] overflow-y-auto overflow-x-hidden"
      >
        <Phoenix.Component.focus_wrap
          :if={@load_content?}
          phx-mounted={
            LiveView.JS.show(
              time: 300,
              transition:
                {"ease-out duration-300", "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
                 "opacity-100 translate-y-0 sm:scale-100"}
            )
          }
          id={@dialog_id}
          class={@class}
          x-show="modalOpen"
          x-transition:enter="transition ease-out duration-300"
          x-transition:enter-start="opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"
          x-transition:enter-end="opacity-100 translate-y-0 sm:scale-100"
          x-transition:leave="transition ease-in duration-200"
          x-transition:leave-start="opacity-100 translate-y-0 sm:scale-100"
          x-transition:leave-end="opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"
          x-on:click.outside="closeModal()"
        >
          {render_slot(@inner_block, modal_unique_id(@modal_sequence_id))}
        </Phoenix.Component.focus_wrap>
        <div x-show="modalOpen" class="modal-loading hidden w-full self-center">
          <div class="text-center">
            <.spinner class="inline-block h-8 w-8" />
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
    socket =
      socket
      |> assign(:load_content?, false)
      |> update(:modal_sequence_id, &(&1 + 1))

    {:noreply, socket}
  end

  defp modal_unique_id(sequence_id) do
    "modalseq#{sequence_id}"
  end
end
