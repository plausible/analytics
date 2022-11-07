defmodule PlausibleWeb.Email do
  use Bamboo.Phoenix, view: PlausibleWeb.EmailView
  import Bamboo.PostmarkHelper

  def mailer_email_from do
    Application.get_env(:plausible, :mailer_email)
  end

  def activation_email(user, code) do
    base_email()
    |> to(user)
    |> tag("activation-email")
    |> subject("#{code} es tu código de verificación")
    |> render("activation_email.html", user: user, code: code)
  end

  def welcome_email(user) do
    base_email()
    |> to(user)
    |> tag("welcome-email")
    |> subject("Bienvenido a nuestras estadísticas!")
    |> render("welcome_email.html", user: user)
  end

  def create_site_email(user) do
    base_email()
    |> to(user)
    |> tag("create-site-email")
    |> subject("Agrega los detalles de tu sitio")
    |> render("create_site_email.html", user: user)
  end

  def site_setup_help(user, site) do
    base_email()
    |> to(user)
    |> tag("help-email")
    |> subject("Esperando las primeras visitas")
    |> render("site_setup_help_email.html", user: user, site: site)
  end

  def site_setup_success(user, site) do
    base_email()
    |> to(user)
    |> tag("setup-success-email")
    |> subject("Estamos registrando las estadísticas")
    |> render("site_setup_success_email.html", user: user, site: site)
  end

  def check_stats_email(user) do
    base_email()
    |> to(user)
    |> tag("check-stats-email")
    |> subject("Chequea las estadísticas")
    |> render("check_stats_email.html", user: user)
  end

  def password_reset_email(email, reset_link) do
    base_email()
    |> to(email)
    |> tag("password-reset-email")
    |> subject("Reiniciamos tu contraseña")
    |> render("password_reset_email.html", reset_link: reset_link)
  end

  def trial_one_week_reminder(user) do
    base_email()
    |> to(user)
    |> tag("trial-one-week-reminder")
    |> subject("Tu cuenta trial expira en una semana")
    |> render("trial_one_week_reminder.html", user: user)
  end

  def trial_upgrade_email(user, day, {pageviews, custom_events}) do
    suggested_plan = Plausible.Billing.Plans.suggested_plan(user, pageviews + custom_events)

    base_email()
    |> to(user)
    |> tag("trial-upgrade-email")
    |> subject("Tu cuenta trial expira en #{day} días")
    |> render("trial_upgrade_email.html",
      user: user,
      day: day,
      custom_events: custom_events,
      usage: pageviews + custom_events,
      suggested_plan: suggested_plan
    )
  end

  def trial_over_email(user) do
    base_email()
    |> to(user)
    |> tag("trial-over-email")
    |> subject("Tu período a prueba finalizó!")
    |> render("trial_over_email.html", user: user)
  end

  def weekly_report(email, site, assigns) do
    base_email()
    |> to(email)
    |> tag("weekly-report")
    |> subject("#{assigns[:name]} reporte para #{site.domain}")
    |> render("weekly_report.html", Keyword.put(assigns, :site, site))
  end

  def spike_notification(email, site, current_visitors, sources, dashboard_link) do
    base_email()
    |> to(email)
    |> tag("spike-notification")
    |> subject("Hype en #{site.domain}!")
    |> render("spike_notification.html", %{
      site: site,
      current_visitors: current_visitors,
      sources: sources,
      link: dashboard_link
    })
  end

  def over_limit_email(user, usage, last_cycle, suggested_plan) do
    base_email()
    |> to(user)
    |> tag("over-limit")
    |> subject("[Acción requerida] Superaste tu plan!")
    |> render("over_limit.html", %{
      user: user,
      usage: usage,
      last_cycle: last_cycle,
      suggested_plan: suggested_plan
    })
  end

  def enterprise_over_limit_internal_email(user, usage, last_cycle, site_usage, site_allowance) do
    base_email()
    |> to("enterprise@plausible.io")
    |> tag("enterprise-over-limit")
    |> subject("#{user.email} superó su plan")
    |> render("enterprise_over_limit_internal.html", %{
      user: user,
      usage: usage,
      last_cycle: last_cycle,
      site_usage: site_usage,
      site_allowance: site_allowance
    })
  end

  def dashboard_locked(user, usage, last_cycle, suggested_plan) do
    base_email()
    |> to(user)
    |> tag("dashboard-locked")
    |> subject("[Acción requerida] Tu panel de estadísticas está bloqueado")
    |> render("dashboard_locked.html", %{
      user: user,
      usage: usage,
      last_cycle: last_cycle,
      suggested_plan: suggested_plan
    })
  end

  def yearly_renewal_notification(user) do
    date = Timex.format!(user.subscription.next_bill_date, "{Mfull} {D}, {YYYY}")

    base_email()
    |> to(user)
    |> tag("yearly-renewal")
    |> subject("Tu suscripción está por renovarse")
    |> render("yearly_renewal_notification.html", %{
      user: user,
      date: date,
      next_bill_amount: user.subscription.next_bill_amount,
      currency: user.subscription.currency_code
    })
  end

  def yearly_expiration_notification(user) do
    date = Timex.format!(user.subscription.next_bill_date, "{Mfull} {D}, {YYYY}")

    base_email()
    |> to(user)
    |> tag("yearly-expiration")
    |> subject("Tu subscripción está por expirar")
    |> render("yearly_expiration_notification.html", %{
      user: user,
      date: date
    })
  end

  def cancellation_email(user) do
    base_email()
    |> to(user.email)
    |> tag("cancelled-email")
    |> subject("Tu subscripción fue cancelada")
    |> render("cancellation_email.html", name: user.name)
  end

  def new_user_invitation(invitation) do
    base_email()
    |> to(invitation.email)
    |> tag("new-user-invitation")
    |> subject("Fuiste invitado a #{invitation.site.domain}")
    |> render("new_user_invitation.html",
      invitation: invitation
    )
  end

  def existing_user_invitation(invitation) do
    base_email()
    |> to(invitation.email)
    |> tag("existing-user-invitation")
    |> subject("Fuiste invitado a #{invitation.site.domain}")
    |> render("existing_user_invitation.html",
      invitation: invitation
    )
  end

  def ownership_transfer_request(invitation, new_owner_account) do
    base_email()
    |> to(invitation.email)
    |> tag("ownership-transfer-request")
    |> subject("Transferir propiedad a #{invitation.site.domain}")
    |> render("ownership_transfer_request.html",
      invitation: invitation,
      new_owner_account: new_owner_account
    )
  end

  def invitation_accepted(invitation) do
    base_email()
    |> to(invitation.inviter.email)
    |> tag("invitation-accepted")
    |> subject(
      "#{invitation.email} aceptó tu invitación a #{invitation.site.domain}"
    )
    |> render("invitation_accepted.html",
      invitation: invitation
    )
  end

  def invitation_rejected(invitation) do
    base_email()
    |> to(invitation.inviter.email)
    |> tag("invitation-rejected")
    |> subject(
      "#{invitation.email} rechazó tu invitación a #{invitation.site.domain}"
    )
    |> render("invitation_rejected.html",
      invitation: invitation
    )
  end

  def ownership_transfer_accepted(invitation) do
    base_email()
    |> to(invitation.inviter.email)
    |> tag("ownership-transfer-accepted")
    |> subject(
      "#{invitation.email} aceptó la transferencia de #{invitation.site.domain}"
    )
    |> render("ownership_transfer_accepted.html",
      invitation: invitation
    )
  end

  def ownership_transfer_rejected(invitation) do
    base_email()
    |> to(invitation.inviter.email)
    |> tag("ownership-transfer-rejected")
    |> subject(
      "#{invitation.email} rechazó la transferencia de #{invitation.site.domain}"
    )
    |> render("ownership_transfer_rejected.html",
      invitation: invitation
    )
  end

  def site_member_removed(membership) do
    base_email()
    |> to(membership.user.email)
    |> tag("site-member-removed")
    |> subject("Tu acceso a #{membership.site.domain} fue revocado")
    |> render("site_member_removed.html",
      membership: membership
    )
  end

  def import_success(user, site) do
    base_email()
    |> to(user)
    |> tag("import-success-email")
    |> subject("La carga de GA finalizó para #{site.domain}")
    |> render("google_analytics_import.html", %{
      site: site,
      link: PlausibleWeb.Endpoint.url() <> "/" <> URI.encode_www_form(site.domain),
      user: user,
      success: true
    })
  end

  def import_failure(user, site) do
    base_email()
    |> to(user)
    |> tag("import-failure-email")
    |> subject("La carga de GA falló en #{site.domain}")
    |> render("google_analytics_import.html", %{
      user: user,
      site: site,
      success: false
    })
  end

  defp base_email() do
    mailer_from = Application.get_env(:plausible, :mailer_email)

    new_email()
    |> put_param("TrackOpens", false)
    |> from(mailer_from)
  end
end
