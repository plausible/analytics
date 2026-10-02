defmodule PlausibleWeb.Live.TeamForce2FASettings do
  @moduledoc """
  LiveView for the "Force Two-Factor Authentication (2FA)" tile in team settings.
  """

  use PlausibleWeb, :live_view

  alias PlausibleWeb.Live.Components.PrimaModal

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       force_2fa_enabled?: Plausible.Teams.force_2fa_enabled?(socket.assigns.current_team)
     )}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.tile docs="2fa#require-all-team-members-to-enable-2fa">
        <:title>
          <a id="force-2fa">Enforce Two-Factor Authentication (2FA)</a>
        </:title>
        <:subtitle>
          Increase account security by requiring all team members to enable 2FA.
        </:subtitle>

        <div :if={@force_2fa_enabled?} id="disable-force-2fa">
          <.button
            theme="danger"
            phx-click={Prima.Modal.JS.open("disable-force-2fa-modal")}
          >
            Stop enforcing 2FA
          </.button>

          <PrimaModal.modal id="disable-force-2fa-modal">
            <div class="p-5 sm:p-6 max-w-md">
              <div class="hidden sm:block absolute top-0 right-0 pt-4 pr-4">
                <button
                  phx-click={Prima.Modal.JS.close()}
                  class="text-gray-400 dark:text-gray-500 hover:text-gray-500 dark:hover:text-gray-400"
                >
                  <span class="sr-only">Close</span>
                  <Heroicons.x_mark class="size-6" />
                </button>
              </div>
              <div class="flex flex-col gap-y-4 text-center sm:text-left">
                <PrimaModal.modal_title>
                  Stop enforcing 2FA?
                </PrimaModal.modal_title>
                <p class="text-sm text-gray-600 dark:text-gray-400">
                  This will remove the 2FA requirement for all team members.
                  Enter your password to stop enforcing 2FA.
                </p>
                <.form
                  action={~p"/settings/team/force_2fa/disable"}
                  for={%{}}
                  method="post"
                  class="flex flex-col gap-y-6"
                >
                  <.input
                    data-autofocus
                    type="password"
                    id="disable_team_force_2fa_password"
                    name="password"
                    value=""
                    placeholder="Enter password"
                  />
                  <.button type="submit" class="w-full">
                    Stop enforcing 2FA
                  </.button>
                </.form>
              </div>
            </div>
          </PrimaModal.modal>
        </div>

        <div :if={not @force_2fa_enabled?} id="enable-force-2fa">
          <.button phx-click={Prima.Modal.JS.open("enable-force-2fa-modal")}>
            Enforce 2FA
          </.button>

          <PrimaModal.modal id="enable-force-2fa-modal">
            <div class="p-5 sm:p-6 max-w-md">
              <div class="hidden sm:block absolute top-0 right-0 pt-4 pr-4">
                <button
                  phx-click={Prima.Modal.JS.close()}
                  class="text-gray-400 dark:text-gray-500 hover:text-gray-500 dark:hover:text-gray-400"
                >
                  <span class="sr-only">Close</span>
                  <Heroicons.x_mark class="size-6" />
                </button>
              </div>
              <div class="flex flex-col gap-y-4 text-center sm:text-left">
                <PrimaModal.modal_title>
                  Enforce 2FA?
                </PrimaModal.modal_title>
                <p class="text-sm text-gray-600 dark:text-gray-400">
                  All team members, including you, will need to set up 2FA.
                </p>
                <.form
                  action={~p"/settings/team/force_2fa/enable"}
                  for={%{}}
                  method="post"
                  class="mt-2"
                >
                  <.button type="submit" class="w-full" data-autofocus>
                    Enforce 2FA
                  </.button>
                </.form>
              </div>
            </div>
          </PrimaModal.modal>
        </div>
      </.tile>
    </div>
    """
  end
end
