defmodule PlausibleWeb.Live.Components.VerificationBanner do
  @moduledoc """
  This component is responsible for rendering the verification progress
  and diagnostics as a compact banner on top of the dashboard.
  """
  use Phoenix.LiveComponent
  use Plausible

  alias PlausibleWeb.Router.Helpers, as: Routes
  alias Plausible.InstallationSupport.{State, Result}

  import PlausibleWeb.Components.Generic
  import PlausibleWeb.Live.Components.Form

  @container_id "verification-ui"

  # All query params the verification LiveView needs must be listed here, so
  # they can be cleaned up from the URL once verification finishes.
  @query_params ~w(verify_installation flow)
  def query_params, do: @query_params

  attr(:domain, :string, required: true)

  attr(:message, :string,
    default: "We're visiting your site to ensure that everything is working"
  )

  attr(:super_admin?, :boolean, default: false)
  attr(:finished?, :boolean, default: false)
  attr(:success?, :boolean, default: false)
  attr(:verification_state, State, default: nil)
  attr(:interpretation, Result, default: nil)
  attr(:attempts, :integer, default: 0)
  attr(:flow, :string, default: "")
  attr(:custom_url_input?, :boolean, default: false)
  attr(:dismissed?, :boolean, default: false)

  def render(assigns) do
    assigns =
      assigns
      |> assign(:container_id, @container_id)
      |> assign(:query_params, @query_params)

    ~H"""
    <div id={@container_id} class={["relative mb-4", @dismissed? && "hidden"]}>
      <.dismiss_button container_id={@container_id} query_params={@query_params} />
      <.render_progress :if={not @finished?} message={@message} />
      <.render_success
        :if={@finished? and @success?}
        domain={@domain}
        super_admin?={@super_admin?}
        verification_state={@verification_state}
      />
      <.render_failed
        :if={@finished? and not @success?}
        interpretation={@interpretation}
        attempts={@attempts}
        domain={@domain}
        flow={@flow}
        super_admin?={@super_admin?}
        verification_state={@verification_state}
        custom_url_input?={@custom_url_input?}
      />
    </div>
    """
  end

  # The action of dismissing the verification banner consists of 4
  # independent things:
  #
  #   1. Client-side: the inlined `onclick` instantly adds the `hidden`
  #      class straight to the container div.
  #
  #   2. Client-side: instantly dispatches a `verification-finished`
  #      window event so React router can clean up query params that are
  #      no longer needed (see assets/js/dashboard/verification/portal.tsx).
  #      Also makes sure that a refresh won't bring verification back.
  #
  #   3. Server-side (phx-click="dismiss"): sets `dismissed?` on this
  #      component's assigns, so it stays hidden even if a later
  #      `send_update` (e.g. :all_checks_done) re-renders it.
  #
  #   4. Server-side, same handler: tells the client to close the websocket
  #      connection, since the LiveView has nothing left to do.
  defp dismiss_button(assigns) do
    ~H"""
    <button
      type="button"
      aria-label="Dismiss"
      class="absolute right-2 top-2 z-10 rounded p-1 text-gray-800 hover:text-gray-600 dark:text-gray-100/60 dark:hover:text-gray-100/70"
      onclick={dismiss_onclick(@container_id, @query_params)}
      phx-click="dismiss"
    >
      <Heroicons.x_mark class="size-4" />
    </button>
    """
  end

  defp dismiss_onclick(container_id, query_params) do
    "document.getElementById('#{container_id}').classList.add('hidden');" <>
      "window.dispatchEvent(new CustomEvent('verification-finished', { detail: { queryParams: #{Jason.encode!(query_params)} } }));"
  end

  defp render_progress(assigns) do
    ~H"""
    <.notice
      title="Verifying your installation"
      theme={:indigo}
      title_class="text-base font-semibold text-gray-900 dark:text-gray-100"
    >
      <:icon>
        <.spinner class="mt-0.5 size-4.5" />
      </:icon>
      <p class="animate-pulse text-gray-800 dark:text-gray-200 text-pretty" id="progress">
        {@message}...
      </p>
    </.notice>
    """
  end

  defp render_success(assigns) do
    ~H"""
    <.notice
      title="Tracking is active on your site"
      theme={:green}
      title_class="text-base font-semibold text-green-800 dark:text-green-300"
      icon_class="!mt-0.5 size-5 text-green-800 dark:text-green-300"
    >
      <:icon>
        <Heroicons.check_circle solid id="check-circle" />
      </:icon>
      <p class="text-gray-800 dark:text-gray-200 text-pretty">
        Your dashboard is ready. Data will appear here as soon as visitors start arriving.
      </p>
      <.super_admin_diagnostics
        :if={@super_admin? and not is_nil(@verification_state)}
        verification_state={@verification_state}
      />
    </.notice>
    """
  end

  defp render_failed(assigns) do
    assigns =
      assign(
        assigns,
        :offer_custom_url_input?,
        offer_custom_url_input?(assigns.interpretation)
      )

    ~H"""
    <.notice
      title={
        if @interpretation,
          do: List.first(@interpretation.errors),
          else: "We couldn't verify your installation"
      }
      theme={:yellow}
      show_icon={false}
      title_class="text-base font-semibold text-yellow-800 dark:text-yellow-400"
    >
      <.recommendation
        :if={@interpretation}
        interpretation={@interpretation}
        offer_custom_url_input?={@offer_custom_url_input?}
        domain={@domain}
        flow={@flow}
      />
      <div class="mt-5 flex flex-wrap items-center gap-2">
        <.retry_form_or_button custom_url_input?={@custom_url_input?} domain={@domain} />
        <.button_link
          :if={not @custom_url_input? and @offer_custom_url_input?}
          mt?={false}
          href="#"
          phx-click="show-custom-url-form"
          id="verify-custom-url-link"
          theme="ghost"
          size="sm"
          class="hover:bg-gray-600/10 dark:hover:bg-white/10 hover:border-transparent dark:hover:border-transparent"
        >
          Try another URL
        </.button_link>
        <.button_link
          :if={not @custom_url_input? and not @offer_custom_url_input?}
          mt?={false}
          href={Routes.site_path(PlausibleWeb.Endpoint, :installation, @domain, flow: @flow)}
          theme="ghost"
          size="sm"
          class="hover:bg-gray-600/10 dark:hover:bg-white/10 hover:border-transparent dark:hover:border-transparent"
        >
          Review installation
        </.button_link>
      </div>
      <.contact_us_link :if={ee?() and @attempts >= 3} />
      <.super_admin_diagnostics
        :if={@super_admin? and not is_nil(@verification_state)}
        verification_state={@verification_state}
      />
    </.notice>
    """
  end

  defp offer_custom_url_input?(interpretation) do
    match?(%{data: %{offer_custom_url_input: true}}, interpretation)
  end

  defp recommendation(assigns) do
    recommendation = List.first(assigns.interpretation.recommendations)
    main = render_recommendation(recommendation.text, recommendation.inline_links)

    body =
      if assigns.offer_custom_url_input? do
        [main, ". ", review_installation_link_sentence(assigns), "."]
      else
        [main, "."]
      end

    assigns = assign(assigns, :body, body)

    ~H"""
    <p id="recommendation" class="text-gray-800 dark:text-gray-200 text-pretty">
      {@body}
    </p>
    """
  end

  defp render_recommendation(text, inline_links) do
    html =
      Enum.reduce(inline_links, html_escape(text), fn %{text: link_text, href: href}, acc ->
        String.replace(acc, link_text, link_markup(link_text, href), global: false)
      end)

    Phoenix.HTML.raw(html)
  end

  defp review_installation_link_sentence(assigns) do
    review_installation_url =
      Routes.site_path(PlausibleWeb.Endpoint, :installation, assigns.domain, flow: assigns.flow)

    render_recommendation("See your installation instructions again here", [
      %{text: "here", href: review_installation_url}
    ])
  end

  defp link_markup(text, href) do
    external_attrs =
      if String.starts_with?(href, "http"),
        do: ~s| target="_blank" rel="noopener noreferrer"|,
        else: ""

    ~s|<a href="#{html_escape(href)}" class="underline"#{external_attrs}>#{html_escape(text)}</a>|
  end

  defp html_escape(value) do
    value |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
  end

  defp retry_form_or_button(%{custom_url_input?: true} = assigns) do
    ~H"""
    <form phx-submit="verify-custom-url" class="flex items-center gap-2">
      <.input
        type="url"
        name="custom_url"
        id="custom_url"
        aria-label="Website URL"
        required
        mt?={false}
        width="w-64 h-[38px] dark:bg-white/15 dark:border-transparent"
        placeholder={"https://#{@domain}"}
        value={"https://#{@domain}"}
      />
      <.button type="submit" mt?={false} theme="primary" size="sm">
        Verify URL
      </.button>
    </form>
    """
  end

  defp retry_form_or_button(assigns) do
    ~H"""
    <.button_link
      mt?={false}
      href="#"
      phx-click="retry"
      theme="secondary"
      size="sm"
      class="dark:bg-white/15 dark:hover:bg-white/20 dark:border-transparent"
    >
      Check again
    </.button_link>
    """
  end

  defp contact_us_link(assigns) do
    ~H"""
    <p class="mt-5 text-[0.825rem] text-gray-800 dark:text-gray-200">
      Need help? {Phoenix.HTML.raw(link_markup("Contact us", "https://plausible.io/contact"))}
    </p>
    """
  end

  defp super_admin_diagnostics(assigns) do
    ~H"""
    <div
      class="mt-5 flex flex-col dark:text-gray-200"
      x-data="{ showDiagnostics: false }"
      id="super-admin-report"
    >
      <p class="text-sm text-gray-800 dark:text-gray-200">
        <a
          href="#"
          @click.prevent="showDiagnostics = !showDiagnostics"
          class="bg-yellow-100 dark:bg-yellow-800/40"
        >
          As a super-admin, you're eligible to see diagnostics details. Click to expand.
        </a>
      </p>
      <div x-show="showDiagnostics" x-cloak>
        <.focus_list>
          <:item :for={{diag, value} <- Map.from_struct(@verification_state.diagnostics)}>
            <span class="text-sm">
              {Phoenix.Naming.humanize(diag)}: <span class="font-mono">{to_string_value(value)}</span>
            </span>
          </:item>
        </.focus_list>
      </div>
    </div>
    """
  end

  defp to_string_value(value) when is_binary(value), do: value
  defp to_string_value(value), do: inspect(value)
end
