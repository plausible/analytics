defmodule PlausibleWeb.Live.ChangeDomain do
  @moduledoc """
  LiveView for the change domain flow.
  """
  use Plausible
  use PlausibleWeb, :live_view

  alias PlausibleWeb.Router.Helpers, as: Routes
  alias PlausibleWeb.Live.ChangeDomain.Form
  alias Phoenix.LiveView.AsyncResult

  on_ee do
    alias Plausible.InstallationSupport.{Detection, Result}
  end

  @change_domain_docs_link "https://plausible.io/docs/change-domain-name"
  @change_domain_checklist_docs_link "https://plausible.io/docs/change-domain-name#domain-change-checklist"

  def change_domain_docs_link(), do: @change_domain_docs_link

  def change_domain_checklist_docs_link(), do: @change_domain_checklist_docs_link

  def mount(
        %{"domain" => domain},
        _session,
        socket
      ) do
    site =
      Plausible.Sites.get_for_user!(socket.assigns.current_user, domain,
        roles: [
          :editor,
          :owner,
          :admin,
          :super_admin
        ]
      )

    {:ok,
     assign(socket,
       site: site,
       detection_result: AsyncResult.loading()
     )}
  end

  on_ee do
    def handle_params(_params, _url, socket) do
      socket =
        if socket.assigns.live_action == :success and connected?(socket) do
          site_domain = socket.assigns.site.domain

          assign_async(socket, :detection_result, fn ->
            run_detection(site_domain)
          end)
        else
          socket
        end

      {:noreply, socket}
    end
  else
    def handle_params(_params, _url, socket) do
      {:noreply, socket}
    end
  end

  def render(%{live_action: :change_domain} = assigns) do
    render_form_step(assigns)
  end

  def render(%{live_action: :success} = assigns) do
    render_success_step(assigns)
  end

  defp render_form_step(assigns) do
    assigns = assign(assigns, docs_link: @change_domain_docs_link)

    ~H"""
    <.focus_box>
      <:title>Change your website domain</:title>
      <:subtitle>
        If you have changed the domain name of your site and would like your new domain name to be displayed in your Plausible dashboard, you can do so here. You won't lose any of your historical stats in this process.
      </:subtitle>

      <:footer>
        <.focus_list>
          <:item>
            See our
            <.styled_link new_tab={true} href={@docs_link}>
              domain change documentation
            </.styled_link>
          </:item>
          <:item>
            Return to
            <.styled_link href={Routes.site_path(@socket, :settings_general, @site.domain)}>
              Site Settings
            </.styled_link>
          </:item>
        </.focus_list>
      </:footer>

      <.live_component module={Form} id="change-domain-form" site={@site} />
    </.focus_box>
    """
  end

  defp render_success_step(assigns) do
    assigns = assign(assigns, docs_link: @change_domain_docs_link)

    ~H"""
    <.focus_box>
      <:title>Domain Changed Successfully</:title>
      <:subtitle>
        Your website domain has been successfully updated from
        <strong>{@site.domain_changed_from}</strong>
        to <strong><%= @site.domain %></strong>.
      </:subtitle>

      <:footer>
        <.focus_list>
          <:item>
            See our
            <.styled_link new_tab={true} href={@docs_link}>
              domain change documentation
            </.styled_link>
          </:item>
          <:item>
            Return to
            <.styled_link href={Routes.site_path(@socket, :settings_general, @site.domain)}>
              Site Settings
            </.styled_link>
          </:item>
        </.focus_list>
      </:footer>
      <%= on_ee do %>
        <.async_result :let={detection_result} assign={@detection_result}>
          <:loading>
            <div class="flex items-center">
              <.spinner class="w-4 h-4 mr-2" />
              <span class="text-sm text-gray-600 dark:text-gray-400">
                Checking your new domain...
              </span>
            </div>
          </:loading>

          <:failed>
            <div class="flex items-center">
              <Heroicons.exclamation_triangle class="w-4 h-4 mr-2 text-yellow-500" />
              <span class="text-sm font-bold">
                We could not reach your new domain
              </span>
            </div>

            <p class="mt-4 text-sm">
              Additional action may be required. If you're using our legacy snippet (i.e. your
              Plausible snippet includes the data-domain attribute) or the NPM package, you must
              also update the site domain of your Plausible installation within 72 hours to match
              the updated domain in order to guarantee continuous tracking.
            </p>
          </:failed>

          <.render_detection_result
            :if={detection_result}
            detection_result={detection_result}
            site={@site}
          />
        </.async_result>
      <% else %>
        <.ce_generic_notice />
      <% end %>
    </.focus_box>
    """
  end

  on_ee do
    defp render_detection_result(assigns) do
      case assigns.detection_result do
        %{v1_detected: true, wordpress_plugin: true} ->
          ~H"""
          <.additional_action_required />
          <.v1_wordpress_plugin_notice />
          """

        %{v1_detected: true} ->
          ~H"""
          <.additional_action_required />
          <.v1_generic_notice site={@site} />
          """

        %{v1_detected: false, npm: true} ->
          ~H"""
          <.additional_action_required />
          <.npm_notice />
          """

        _ ->
          ~H"""
          <.success_notice />
          <.tracking_works_notice />
          """
      end
    end

    defp success_notice(assigns) do
      ~H"""
      <div class="flex items-center">
        <Heroicons.check class="w-4 h-4 mr-2 text-green-500" />
        <span class="text-sm font-bold">
          Your new domain should be tracking nicely
        </span>
      </div>
      """
    end

    defp additional_action_required(assigns) do
      ~H"""
      <div class="flex items-center">
        <Heroicons.exclamation_triangle class="w-4 h-4 mr-2 text-yellow-500" />
        <span class="text-sm font-bold">
          Additional action required
        </span>
      </div>
      """
    end

    defp v1_wordpress_plugin_notice(assigns) do
      # A v2 tracker based WordPress plugin is not yet ready so the WP plugin users
      # need to change their site domain instead of upgrading to script v2.
      ~H"""
      <p class="mt-4 text-sm">
        We've detected you're using our WordPress plugin. To guarantee continuous tracking,
        you must also update the site domain in your Plausible Wordpress Plugin settings
        within 72 hours to match the updated domain.
      </p>
      """
    end

    defp v1_generic_notice(assigns) do
      ~H"""
      <p class="mt-4 text-sm">
        We've detected you're using our legacy script. This means that you'll also need
        to update the site domain of your Plausible installation within 72 hours to guarantee
        continuous tracking. The easiest way to fix that is to simply follow your
        <.styled_link
          new_tab
          href={Routes.site_path(PlausibleWeb.Endpoint, :installation, @site.domain)}
        >
          installation instructions
        </.styled_link>
        and upgrade to our new, more powerful tracking script.
      </p>
      """
    end

    defp npm_notice(assigns) do
      ~H"""
      <p class="mt-4 text-sm">
        We've detected you're using our @plausible-analytics/tracker module. This means that you'll also need
        to update the site domain of your Plausible installation within 72 hours to
        guarantee continuous tracking.
      </p>
      """
    end

    defp tracking_works_notice(assigns) do
      assigns = assign(assigns, :docs_link, @change_domain_checklist_docs_link)

      ~H"""
      <p class="mt-4 text-sm">
        Take a quick look at our
        <.styled_link new_tab href={@docs_link}>
          domain change checklist
        </.styled_link>
        to make sure no further action is needed.
      </p>
      """
    end

    defp run_detection(domain) do
      with {:ok, detection_result} <-
             Detection.Checks.run_with_rate_limit(nil, domain,
               detection_check_timeout: 11_000,
               detect_v1?: true,
               report_to: nil,
               async?: false,
               slowdown: 0
             ),
           %Result{ok?: true, data: data} <-
             Detection.Checks.interpret_diagnostics(detection_result) do
        {:ok, %{detection_result: data}}
      else
        %Result{ok?: false, errors: errors} ->
          {:error, List.first(errors, :unknown_reason)}

        {:error, {:rate_limit_exceeded, _}} ->
          {:error, :rate_limit_exceeded}
      end
    end
  else
    defp ce_generic_notice(assigns) do
      ~H"""
      <div class="flex items-center">
        <Heroicons.exclamation_triangle class="w-4 h-4 mr-2 text-yellow-500" />
        <span class="text-sm font-bold">
          Additional action may be required
        </span>
      </div>
      <p class="mt-4 text-sm">
        If you're using our legacy snippet (i.e. your Plausible snippet includes the
        data-domain attribute) or the NPM package, you must also update the site domain
        of your Plausible installation within 72 hours to match the updated domain in
        order to guarantee continuous tracking.
      </p>
      """
    end
  end

  def handle_info({:domain_changed, updated_site}, socket) do
    PlausibleWeb.Tracker.purge_tracker_script_cache!(updated_site)

    {:noreply,
     socket
     |> assign(site: updated_site)
     |> push_patch(to: Routes.site_path(socket, :success, updated_site.domain))}
  end
end
