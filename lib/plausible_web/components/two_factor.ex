defmodule PlausibleWeb.Components.TwoFactor do
  @moduledoc """
  Reusable components specific to 2FA
  """
  use Phoenix.Component, global_prefixes: ~w(x-)
  import PlausibleWeb.Components.Generic

  attr :text, :string, required: true
  attr :scale, :integer, default: 4

  def qr_code(assigns) do
    qr_code =
      assigns.text
      |> EQRCode.encode()
      |> EQRCode.svg(%{width: 160})

    assigns = assign(assigns, :code, qr_code)

    ~H"""
    <%= Phoenix.HTML.raw(@code) %>
    """
  end

  attr :id, :string, default: "verify-button"
  attr :form, :any, required: true
  attr :field, :any, required: true
  attr :class, :string, default: ""
  attr :show_button?, :boolean, default: true

  def verify_2fa_input(assigns) do
    input_class =
      "font-mono tracking-[0.5em] w-36 pl-5 font-medium shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block border-gray-300 dark:border-gray-500 dark:text-gray-200 dark:bg-gray-900 rounded-l-md"

    input_class =
      if assigns.show_button? do
        input_class
      else
        [input_class, "rounded-r-md"]
      end

    assigns = assign(assigns, :input_class, input_class)

    ~H"""
    <div class={[@class, "flex items-center"]}>
      <%= Phoenix.HTML.Form.text_input(@form, @field,
        autocomplete: "off",
        class: @input_class,
        oninput:
          if @show_button? do
            "this.value=this.value.replace(/[^0-9]/g, ''); if (this.value.length >= 6) document.getElementById('#{@id}').focus()"
          else
            "this.value=this.value.replace(/[^0-9]/g, '');"
          end,
        onclick: "this.select();",
        oninvalid: @show_button? && "document.getElementById('#{@id}').disabled = false",
        maxlength: "6",
        placeholder: "••••••",
        value: "",
        required: "required"
      ) %>
      <PlausibleWeb.Components.Generic.button
        :if={@show_button?}
        type="submit"
        id={@id}
        mt?={false}
        class="rounded-l-none [&>span.label-enabled]:block [&>span.label-disabled]:hidden [&[disabled]>span.label-enabled]:hidden [&[disabled]>span.label-disabled]:block"
      >
        <span class="label-enabled pointer-events-none">
          Verify &rarr;
        </span>

        <span class="label-disabled">
          <PlausibleWeb.Components.Generic.spinner class="inline-block h-5 w-5 mr-2 text-white dark:text-gray-400" />
          Verifying...
        </span>
      </PlausibleWeb.Components.Generic.button>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :state_param, :string, required: true
  attr :form_data, :any, required: true
  attr :form_target, :string, required: true
  attr :onsubmit, :string, default: nil
  attr :title, :string, required: true

  slot :icon, required: true
  slot :inner_block, required: true
  slot :buttons, required: true

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      x-cloak
      x-show={@state_param}
      x-on:keyup.escape.window={"#{@state_param} = false"}
      class="fixed z-10 inset-0 overflow-y-auto"
      aria-labelledby="modal-title"
      role="dialog"
      aria-modal="true"
    >
      <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
        <div
          x-show={@state_param}
          x-transition:enter="transition ease-out duration-300"
          x-transition:enter-start="opacity-0"
          x-transition:enter-end="opacity-100"
          x-transition:leave="transition ease-in duration-200"
          x-transition:leave-start="opacity-100"
          x-transition:leave-end="opacity-0"
          class="fixed inset-0 bg-gray-500 dark:bg-gray-800 bg-opacity-75 dark:bg-opacity-75 transition-opacity"
          aria-hidden="true"
          x-on:click={"#{@state_param} = false"}
        >
        </div>
        <!-- This element is to trick the browser into centering the modal contents. -->
        <span class="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">
          &#8203;
        </span>

        <div
          x-show={@state_param}
          x-transition:enter="transition ease-out duration-300"
          x-transition:enter-start="opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"
          x-transition:enter-end="opacity-100 translate-y-0 sm:scale-100"
          x-transition:leave="transition ease-in duration-200"
          x-transition:leave-start="opacity-100 translate-y-0 sm:scale-100"
          x-transition:leave-end="opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"
          class="inline-block align-bottom bg-white dark:bg-gray-900 rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full"
        >
          <%= Phoenix.HTML.Form.form_for @form_data, @form_target, [onsubmit: @onsubmit], fn f -> %>
            <div class="bg-white dark:bg-gray-800 px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
              <div class="hidden sm:block absolute top-0 right-0 pt-4 pr-4">
                <a
                  href="#"
                  x-on:click.prevent={"#{@state_param} = false"}
                  class="bg-white dark:bg-gray-800 rounded-md text-gray-400 dark:text-gray-500 hover:text-gray-500 dark:hover:text-gray-400 focus:outline-none"
                >
                  <span class="sr-only">Close</span>
                  <Heroicons.x_mark class="h-6 w-6" />
                </a>
              </div>
              <div class="sm:flex sm:items-start">
                <div class="mx-auto flex-shrink-0 flex items-center justify-center h-12 w-12 rounded-full bg-green-100 sm:mx-0 sm:h-10 sm:w-10">
                  <%= render_slot(@icon) %>
                </div>
                <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left text-gray-900 dark:text-gray-100">
                  <h3 class="text-lg leading-6 font-medium" id="modal-title">
                    <%= @title %>
                  </h3>

                  <%= render_slot(@inner_block, f) %>
                </div>
              </div>
            </div>
            <div class="bg-gray-50 dark:bg-gray-850 px-4 py-3 sm:px-9 sm:flex sm:flex-row-reverse">
              <%= render_slot(@buttons) %>
              <.button
                type="button"
                x-on:click={"#{@state_param} = false"}
                class="w-full sm:w-auto mr-2"
                theme="bright"
              >
                Cancel
              </.button>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
