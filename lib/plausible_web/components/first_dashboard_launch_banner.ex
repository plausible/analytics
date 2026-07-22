defmodule PlausibleWeb.Components.FirstDashboardLaunchBanner do
  @moduledoc """
  Dashboard banner pointing at email reports, shown once a site has stats and
  only to roles that can access the email reports settings. Stays hidden while
  the verification banner is up and reveals itself when that banner is dismissed.
  """

  use PlausibleWeb, :component

  @roles_with_email_reports_access [:owner, :admin, :editor, :super_admin]

  attr(:site, Plausible.Site, required: true)
  attr(:site_role, :atom, required: true)
  attr(:current_user_id, :any, required: true)
  attr(:has_pageviews?, :boolean, required: true)
  attr(:verify_installation?, :boolean, default: false)

  def render(assigns) do
    assigns =
      assign(
        assigns,
        :visible?,
        assigns.has_pageviews? and assigns.site_role in @roles_with_email_reports_access
      )

    ~H"""
    <div
      :if={@visible?}
      x-cloak
      x-data={"{show: #{not @verify_installation?}}"}
      x-bind:class="! show ? 'hidden' : ''"
      x-on:verification-finished.window="show = true"
      role="alert"
    >
      <.notice
        theme={:indigo}
        dismissable_id={"first_dashboard_launched_#{@current_user_id}_#{@site.domain}"}
        class="!p-4 text-center font-medium"
        dismiss_class="top-1/2 -translate-y-1/2 right-4"
      >
        <span class="text-base mr-1">
          🎉
        </span>
        <span class="text-gray-900 dark:text-gray-100">
          Your first pageview has landed!
        </span>
        <.styled_link
          class="plausible-event-name=Weekly+Email+Note+Click"
          href={Routes.site_path(PlausibleWeb.Endpoint, :settings_email_reports, @site.domain)}
          onclick={"localStorage['notice_dismissed__first_dashboard_launched_#{@current_user_id}_#{@site.domain}'] = 'true'"}
        >
          Get weekly traffic reports by email →
        </.styled_link>
      </.notice>
    </div>
    """
  end
end
