defmodule PlausibleWeb.Components.TwoFactor do
  @moduledoc """
  Reusable components specific to 2FA
  """
  use Phoenix.Component

  attr :form, :any, required: true
  attr :field, :any, required: true
  attr :class, :string, default: ""

  def verify_2fa_input(assigns) do
    ~H"""
    <div class={[@class, "flex items-center justify-center sm:justify-start"]}>
      <%= Phoenix.HTML.Form.text_input(@form, @field,
        autocomplete: "off",
        class:
          "font-mono tracking-[0.5em] w-36 pl-5 font-medium shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block border-gray-300 dark:border-gray-500 dark:text-gray-200 dark:bg-gray-900 rounded-l-md",
        oninput:
          "this.value=this.value.replace(/[^0-9]/g, ''); if (this.value.length >= 6) document.getElementById('verify').focus()",
        onclick: "this.select();",
        maxlength: "6",
        placeholder: "••••••",
        value: "",
        required: "required"
      ) %>
      <button id="verify" class="button rounded-l-none">Verify &rarr;</button>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :state_param, :string, required: true
  attr :form_data, :any, required: true
  attr :form_target, :string, required: true
  attr :onsubmit, :string, default: ""
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
              <button
                type="button"
                class="sm:mr-2 mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 dark:border-gray-500 shadow-sm px-4 py-2 bg-white dark:bg-gray-800 text-base font-medium text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-850 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:mt-0 sm:ml-3 sm:w-auto sm:text-sm"
                x-on:click={"#{@state_param} = false"}
              >
                Cancel
              </button>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
