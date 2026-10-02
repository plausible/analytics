defmodule PlausibleWeb.Live.TwoFactorSettings do
  @moduledoc """
  LiveView for the "Two-Factor Authentication (2FA)" tile in account security settings.
  """

  use PlausibleWeb, :live_view

  alias PlausibleWeb.Live.Components.PrimaModal

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket, totp_enabled?: Plausible.Auth.TOTP.enabled?(socket.assigns.current_user))}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.tile docs="2fa">
        <:title>
          <a id="update-2fa">Two-Factor Authentication (2FA)</a>
        </:title>
        <:subtitle>
          Protect your account by adding an extra security step when you log in.
        </:subtitle>

        <div :if={@totp_enabled?}>
          <.button
            disabled={Plausible.Users.type(@current_user) == :sso}
            phx-click={Prima.Modal.JS.open("disable-2fa-modal")}
            theme="danger"
          >
            Disable 2FA
          </.button>

          <p class="mt-2 text-gray-600 text-sm dark:text-gray-400">
            Lost your recovery codes?
            <button
              type="button"
              phx-click={Prima.Modal.JS.open("regenerate-2fa-modal")}
              class="underline text-indigo-600"
            >
              Generate new
            </button>
          </p>

          <PrimaModal.modal id="disable-2fa-modal">
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
                  Disable Two-Factor Authentication?
                </PrimaModal.modal_title>
                <p class="text-sm text-gray-600 dark:text-gray-400">
                  If you turn off 2FA, codes from your authenticator app and your current recovery codes will stop working. To use 2FA again, you’ll need to set it up from scratch.
                </p>
                <p class="text-sm text-gray-600 dark:text-gray-400">
                  Enter your password to continue.
                </p>
                <.form action={~p"/2fa/disable"} for={%{}} method="post" class="flex flex-col gap-y-6">
                  <.input
                    data-autofocus
                    type="password"
                    id="disable_2fa_password"
                    name="password"
                    value=""
                    placeholder="Password"
                  />
                  <.button type="submit" class="w-full">
                    Disable 2FA
                  </.button>
                </.form>
              </div>
            </div>
          </PrimaModal.modal>

          <PrimaModal.modal id="regenerate-2fa-modal">
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
                  Generate new recovery codes?
                </PrimaModal.modal_title>
                <p class="text-sm text-gray-600 dark:text-gray-400">
                  If you generate new recovery codes, the old ones will become invalid.
                  Enter your password to continue.
                </p>
                <.form
                  action={~p"/2fa/recovery_codes"}
                  for={%{}}
                  method="post"
                  onsubmit="document.getElementById('generate-2fa-recovery-button').disabled = true"
                  class="flex flex-col gap-y-6"
                >
                  <.input
                    data-autofocus
                    type="password"
                    id="regenerate_2fa_password"
                    name="password"
                    value=""
                    placeholder="Enter password"
                  />
                  <.button
                    id="generate-2fa-recovery-button"
                    type="submit"
                    class="w-full [&>span.label-enabled]:block [&>span.label-disabled]:hidden [&[disabled]>span.label-enabled]:hidden [&[disabled]>span.label-disabled]:block"
                  >
                    <span class="label-enabled pointer-events-none">
                      Generate new codes
                    </span>

                    <span class="label-disabled">
                      <.spinner class="inline-block h-5 w-5 mr-2 text-white dark:text-gray-400" />
                      Generating codes
                    </span>
                  </.button>
                </.form>
              </div>
            </div>
          </PrimaModal.modal>
        </div>

        <div :if={not @totp_enabled?}>
          <.form action={~p"/2fa/setup/initiate"} for={%{}} method="post">
            <.button type="submit">
              Enable 2FA
            </.button>
          </.form>
        </div>
      </.tile>
    </div>
    """
  end
end
