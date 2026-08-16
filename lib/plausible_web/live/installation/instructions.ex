defmodule PlausibleWeb.Live.Installation.Instructions do
  @moduledoc """
  Instruction forms and components for the Installation module
  """
  use PlausibleWeb, :component

  attr :tracker_script_configuration_form, :map, required: true

  def manual_instructions(assigns) do
    ~H"""
    <div class="flex flex-col gap-3">
      <label class="text-sm font-semibold text-gray-800 dark:text-gray-200">
        Add this snippet to your site's
        <code class="font-mono text-[0.825rem] text-red-700 dark:text-red-400 font-semibold">
          &lt;head&gt;
        </code>
      </label>

      <.code_snippet
        id="manual-snippet"
        text={render_snippet(@tracker_script_configuration_form.data)}
        rows={6}
      />

      <p class="text-sm text-gray-500 dark:text-gray-400">
        Need help?
        <.styled_link
          href="https://plausible.io/docs/plausible-script"
          new_tab={true}
          external_icon={false}
        >
          Read our docs
        </.styled_link>
      </p>
    </div>
    """
  end

  attr :flow, :string, required: true
  attr :recommended_installation_type, :string, required: true

  def wordpress_instructions(assigns) do
    ~H"""
    <div class="flex flex-col gap-6">
      <label class="text-sm font-semibold text-gray-800 dark:text-gray-200">Instructions</label>
      <.steps_list>
        <:step>
          <.styled_link
            href="https://plausible.io/wordpress-analytics-plugin"
            new_tab={true}
            external_icon={false}
          >
            Install our WordPress plugin.
          </.styled_link>
        </:step>
        <:step>Activate the plugin.</:step>
        <:step>Click 'I've installed it' to verify your installation.</:step>
      </.steps_list>
    </div>
    """
  end

  attr :recommended_installation_type, :string, required: true
  attr :tracker_script_configuration_form, :map, required: true

  def gtm_instructions(assigns) do
    ~H"""
    <div class="flex flex-col gap-6">
      <label class="text-sm font-semibold text-gray-800 dark:text-gray-200">Instructions</label>
      <.steps_list>
        <:step>
          <div class="flex flex-col gap-2">
            <span>Copy your Script ID.</span>
            <.code_snippet
              id="gtm-script-id-snippet"
              text={@tracker_script_configuration_form.data.id}
              rows={1}
            />
          </div>
        </:step>
        <:step>
          <.styled_link href="https://plausible.io/gtm-template" new_tab={true} external_icon={false}>
            Install the Plausible template in GTM.
          </.styled_link>
        </:step>
        <:step>Paste your Script ID into the template.</:step>
        <:step>Click 'I've installed it' to verify your installation.</:step>
      </.steps_list>
    </div>
    """
  end

  def npm_instructions(assigns) do
    ~H"""
    <div class="flex flex-col gap-6">
      <label class="text-sm font-semibold text-gray-800 dark:text-gray-200">Instructions</label>
      <.steps_list>
        <:step>
          <.styled_link
            href="https://www.npmjs.com/package/@plausible-analytics/tracker"
            new_tab={true}
            external_icon={false}
          >
            Install @plausible-analytics/tracker NPM package
          </.styled_link>
        </:step>
        <:step>Click 'I've installed it' to verify your installation.</:step>
      </.steps_list>
    </div>
    """
  end

  slot :step, required: true

  defp steps_list(assigns) do
    ~H"""
    <ol class="flex flex-col text-sm text-gray-800 dark:text-gray-200">
      <li
        :for={{step, idx} <- Enum.with_index(@step)}
        class="relative flex items-start gap-3 leading-6 pb-6 last:pb-0"
      >
        <span
          :if={idx + 1 < length(@step)}
          aria-hidden="true"
          class="absolute top-7 bottom-1 left-3 -translate-x-1/2 w-px bg-gray-300 dark:bg-gray-600"
        />
        <span class="shrink-0 size-6 rounded-full border border-gray-300 dark:border-gray-600 text-sm font-medium flex items-center justify-center">
          {idx + 1}
        </span>
        <div class="flex-1 text-base">
          {render_slot(step)}
        </div>
      </li>
    </ol>
    """
  end

  attr :id, :string, required: true
  attr :text, :string, required: true
  attr :rows, :integer, default: 6

  defp code_snippet(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook="CopySnippet"
      data-copied="false"
      class="group relative rounded-lg bg-gray-100 dark:bg-gray-750"
    >
      <textarea
        data-snippet
        name="snippet"
        rows={@rows}
        readonly
        class="block w-full resize-none border-0 bg-transparent px-3 py-3 text-[0.8rem] leading-4.5 font-mono text-gray-800 dark:text-gray-300 selection:bg-gray-200/80 dark:selection:bg-gray-700 focus:outline-none focus:ring-0"
      ><%= @text %></textarea>

      <.button
        type="button"
        theme="secondary"
        size="xs"
        mt?={false}
        class="absolute top-1.5 right-1.5 shadow-xs"
        data-copy
      >
        <span class="inline-flex items-center gap-x-1.5 group-data-[copied=true]:hidden">
          <PlausibleWeb.Components.Icons.copy_icon class="size-3.5" /> Copy
        </span>
        <span class="hidden items-center gap-x-1.5 group-data-[copied=true]:inline-flex">
          <Heroicons.check mini class="size-3.5" /> Copied!
        </span>
      </.button>
    </div>
    """
  end

  defp render_snippet(tracker_script_configuration) do
    """
    <!-- Privacy-friendly analytics by Plausible -->
    <script async src="#{tracker_url(tracker_script_configuration)}"></script>
    <script>
      window.plausible=window.plausible||function(){(plausible.q=plausible.q||[]).push(arguments)},plausible.init=plausible.init||function(i){plausible.o=i||{}};
      plausible.init()
    </script>
    """
  end

  defp tracker_url(tracker_script_configuration) do
    "#{PlausibleWeb.Endpoint.url()}/js/#{tracker_script_configuration.id}.js"
  end
end
