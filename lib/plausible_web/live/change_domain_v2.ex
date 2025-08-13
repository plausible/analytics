defmodule PlausibleWeb.Live.ChangeDomainV2 do
  @moduledoc """
  LiveView for the change domain v2 flow.
  """
  use PlausibleWeb, :live_view

  alias PlausibleWeb.Router.Helpers, as: Routes
  alias PlausibleWeb.Live.ChangeDomainV2.Form
  alias Plausible.InstallationSupport.{Detection, Result}
  alias Phoenix.LiveView.AsyncResult

  def mount(
        %{"domain" => domain},
        _session,
        socket
      ) do
    site =
      Plausible.Sites.get_for_user!(socket.assigns.current_user, domain, [
        :owner,
        :admin,
        :super_admin
      ])

    {:ok,
     assign(socket,
       site: site,
       detection_result: AsyncResult.loading()
     )}
  end

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

  def render(%{live_action: :change_domain_v2} = assigns) do
    render_form_step(assigns)
  end

  def render(%{live_action: :success} = assigns) do
    render_success_step(assigns)
  end

  defp render_form_step(assigns) do
    ~H"""
    <.focus_box>
      <:title>Change your website domain</:title>
      <:subtitle>
        If you have changed the domain name of your site and would like your new domain name to be displayed in your Plausible dashboard, you can do so here. You won't lose any of your historical stats in this process.
      </:subtitle>

      <:footer>
        <.focus_list>
          <:item>
            Changed your mind? Go back to
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
            <.styled_link href={Routes.site_path(@socket, :settings_general, @site.domain)}>
              Go to Site Settings
            </.styled_link>
          </:item>
        </.focus_list>
      </:footer>

      <.async_result :let={detection_result} assign={@detection_result}>
        <:loading>
          <div class="flex items-center">
            <.spinner class="w-4 h-4 mr-2" />
            <span class="text-sm text-gray-600">Checking your new domain...</span>
          </div>
        </:loading>

        <:failed>
          <.generic_notice />
        </:failed>

        <.wordpress_plugin_notice :if={
          detection_result && detection_result.v1_detected && detection_result.wordpress_plugin
        } />
        <.generic_notice :if={
          detection_result && detection_result.v1_detected && !detection_result.wordpress_plugin
        } />
      </.async_result>
    </.focus_box>
    """
  end

  defp wordpress_plugin_notice(assigns) do
    ~H"""
    <.notice class="mt-4" title="Additional Steps Required">
      To guarantee continuous tracking, you <i>must</i>
      also update the site <code>domain</code>
      in your Plausible Wordpress Plugin settings within 72 hours
      to match the updated domain. See
      <.styled_link new_tab href="https://plausible.io/docs/change-domain-name/">
        documentation
      </.styled_link>
      for details.
    </.notice>
    """
  end

  defp generic_notice(assigns) do
    ~H"""
    <.notice class="mt-4" title="Additional Steps Required">
      To guarantee continuous tracking, you <i>must</i>
      also update the site <code>domain</code>
      of your Plausible Installation within 72 hours
      to match the updated domain. See
      <.styled_link new_tab href="https://plausible.io/docs/change-domain-name/">
        documentation
      </.styled_link>
      for details.
    </.notice>
    """
  end

  def handle_info({:domain_changed, updated_site}, socket) do
    {:noreply,
     socket
     |> assign(site: updated_site)
     |> push_patch(to: Routes.site_path(socket, :success, updated_site.domain))}
  end

  defp run_detection(domain) do
    url_to_detect = nil

    case url_to_detect
         |> Detection.Checks.run(domain,
           detect_v1?: true,
           report_to: nil,
           async?: false,
           slowdown: 0
         )
         |> Detection.Checks.interpret_diagnostics() do
      %Result{
        ok?: true,
        data: %{
          v1_detected: v1_detected,
          wordpress_plugin: wordpress_plugin
        }
      } ->
        {:ok,
         %{
           detection_result: %{
             v1_detected: v1_detected,
             wordpress_plugin: wordpress_plugin
           }
         }}

      %Result{ok?: false, errors: errors} ->
        List.first(errors)
    end
  end
end
