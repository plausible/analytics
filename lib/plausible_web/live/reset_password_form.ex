defmodule PlausibleWeb.Live.ResetPasswordForm do
  @moduledoc """
  LiveView for password reset form.
  """

  use PlausibleWeb, :live_view

  alias Plausible.Auth
  alias Plausible.Repo

  def mount(_params, %{"email" => email}, socket) do
    socket =
      assign_new(socket, :user, fn ->
        Repo.get_by!(Auth.User, email: email)
      end)

    changeset = Auth.User.settings_changeset(socket.assigns.user)

    {:ok,
     assign(socket,
       form: to_form(changeset),
       password_strength: Auth.User.password_strength(changeset),
       trigger_submit: false
     )}
  end

  def render(assigns) do
    ~H"""
    <.form
      :let={f}
      for={@form}
      method="post"
      phx-change="validate"
      phx-submit="set"
      phx-trigger-action={@trigger_submit}
      class="flex flex-col gap-y-6"
    >
      <input name="_csrf_token" type="hidden" value={Plug.CSRFProtection.get_csrf_token()} />

      <div class="flex flex-col gap-y-2">
        <label
          for={f[:password].id}
          class="text-sm font-semibold text-gray-800 dark:text-gray-200"
        >
          New password
        </label>
        <div>
          <.password_input_with_strength
            field={f[:password]}
            strength={@password_strength}
            phx-debounce={200}
            mt?={false}
          />
        </div>
        <.password_length_hint minimum={12} field={f[:password]} hide_when_used?={true} />
      </div>

      <div class="flex flex-col gap-y-4">
        <.button id="set" type="submit" class="w-full" mt?={false}>
          Update password
        </.button>

        <p class="text-sm text-center text-gray-500 dark:text-gray-400">
          <.styled_link href="/login">Back to sign in</.styled_link>
        </p>
      </div>
    </.form>
    """
  end

  def handle_event("validate", %{"user" => %{"password" => password}}, socket) do
    changeset =
      socket.assigns.user
      |> Auth.User.set_password(password)
      |> Map.put(:action, :validate)

    password_strength = Auth.User.password_strength(changeset)

    {:noreply, assign(socket, form: to_form(changeset), password_strength: password_strength)}
  end

  def handle_event("set", %{"user" => %{"password" => password}}, socket) do
    result =
      Repo.transaction(fn ->
        changeset = Auth.User.set_password(socket.assigns.user, password)

        case Repo.update(changeset) do
          {:ok, user} ->
            Auth.TOTP.reset_token(user)

          {:error, changeset} ->
            Repo.rollback(changeset)
        end
      end)

    case result do
      {:ok, user} ->
        Auth.UserSessions.revoke_all(user)
        {:noreply, assign(socket, trigger_submit: true)}

      {:error, changeset} ->
        {:noreply,
         assign(socket,
           form: to_form(Map.put(changeset, :action, :validate))
         )}
    end
  end
end
