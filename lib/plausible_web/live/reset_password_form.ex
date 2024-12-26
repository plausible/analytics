defmodule PlausibleWeb.Live.ResetPasswordForm do
  @moduledoc """
  LiveView for password reset form.
  """

  use PlausibleWeb, :live_view

  alias Plausible.Auth
  alias Plausible.Repo
  alias PlausibleWeb.UserAuth

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
      class="bg-white dark:bg-gray-800 max-w-md w-full mx-auto shadow-md rounded px-8 py-6 mt-8"
    >
      <input name="_csrf_token" type="hidden" value={Plug.CSRFProtection.get_csrf_token()} />
      <h2 class="text-xl font-black dark:text-gray-100">
        Reset your password
      </h2>
      <div class="my-4">
        <.password_length_hint
          minimum={12}
          field={f[:password]}
          class={["text-sm", "mt-1", "mb-2"]}
          ok_class="text-gray-600 dark:text-gray-600"
          error_class="text-red-600 dark:text-red-500"
        />
        <.password_input_with_strength
          field={f[:password]}
          strength={@password_strength}
          phx-debounce={200}
          class="transition bg-gray-100 dark:bg-gray-900 outline-none appearance-none border border-transparent rounded w-full p-2 text-gray-700 dark:text-gray-300 leading-normal appearance-none focus:outline-none focus:bg-white dark:focus:bg-gray-800 focus:border-gray-300 dark:focus:border-gray-500"
        />
      </div>
      <.button id="set" type="submit" class="mt-4 w-full">
        Set password →
      </.button>
      <p class="text-center text-gray-500 text-xs mt-4">
        Don't have an account?
        <.styled_link href="/register">Register</.styled_link>
        instead.
      </p>
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
        UserAuth.revoke_all_user_sessions(user)
        {:noreply, assign(socket, trigger_submit: true)}

      {:error, changeset} ->
        {:noreply,
         assign(socket,
           form: to_form(Map.put(changeset, :action, :validate))
         )}
    end
  end
end
