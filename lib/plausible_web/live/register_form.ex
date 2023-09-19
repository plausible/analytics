defmodule PlausibleWeb.Live.RegisterForm do
  @moduledoc """
  LiveView for registration form.
  """

  use Phoenix.LiveView
  use Phoenix.HTML

  import PlausibleWeb.Live.Components.Form

  alias Plausible.Auth
  alias Plausible.Repo

  def mount(_params, %{"is_selfhost" => is_selfhost} = session, socket) do
    {changeset, invitation_id} =
      if invitation_id = session["invitation_id"] do
        invitation = Repo.get_by!(Auth.Invitation, invitation_id: invitation_id)
        {Auth.User.changeset(%Auth.User{email: invitation.email}), invitation.invitation_id}
      else
        {Auth.User.changeset(%Auth.User{}), nil}
      end

    {:ok,
     assign(socket,
       form: to_form(changeset),
       invitation_id: invitation_id,
       captcha_error: nil,
       password_strength: Auth.User.password_strength(changeset),
       is_selfhost: is_selfhost,
       trigger_submit: false
     )}
  end

  def render(assigns) do
    ~H"""
    <.form
      :let={f}
      for={@form}
      phx-change="validate"
      phx-submit="register"
      phx-trigger-action={@trigger_submit}
      class="w-full max-w-md mx-auto bg-white dark:bg-gray-800 shadow-md rounded px-8 py-6 mb-4 mt-8"
    >
      <input name="_csrf_token" type="hidden" value={Plug.CSRFProtection.get_csrf_token()} />
      <input :if={@invitation_id} name="invitation_id" type="hidden" value={@invitation_id} />

      <h2 class="text-xl font-black dark:text-gray-100">Enter your details</h2>

      <%= if @invitation_id do %>
        <.email_input field={f[:email]} invitation_id={@invitation_id} />
        <.name_input field={f[:name]} />
      <% else %>
        <.name_input field={f[:name]} />
        <.email_input field={f[:email]} invitation_id={@invitation_id} />
      <% end %>

      <div class="my-4">
        <div class="flex justify-between">
          <label
            for={f[:password].name}
            class="block text-sm font-medium text-gray-700 dark:text-gray-300"
          >
            Password
          </label>
          <.password_length_hint minimum={12} field={f[:password]} />
        </div>
        <div class="mt-1">
          <.password_input_with_strength
            type="password"
            field={f[:password]}
            strength={@password_strength}
            class="dark:bg-gray-900 shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 dark:border-gray-500 rounded-md dark:text-gray-300"
          />
        </div>
      </div>

      <div class="my-4">
        <label
          for={f[:password_confirmation].name}
          class="block text-sm font-medium text-gray-700 dark:text-gray-300"
        >
          Password confirmation
        </label>
        <div class="mt-1">
          <.input
            type="password"
            field={f[:password_confirmation]}
            class="dark:bg-gray-900 shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 dark:border-gray-500 rounded-md dark:text-gray-300"
          />
        </div>
      </div>

      <%= if PlausibleWeb.Captcha.enabled?() do %>
        <div class="mt-4">
          <div phx-hook="HCaptcha" id="hcaptcha-placeholder" class="h-captcha"></div>
          <%= if @captcha_error do %>
            <div class="text-red-500 text-xs italic mt-3"><%= @captcha_error %></div>
          <% end %>
          <script src="https://hcaptcha.com/1/api.js?render=explicit" async defer>
          </script>
        </div>
      <% end %>

      <% submit_text =
        if @is_selfhost or @invitation_id do
          "Create my account →"
        else
          "Start my free trial →"
        end %>

      <button id="register" type="submit" class="button mt-4 w-full">
        <%= submit_text %>
      </button>

      <p class="text-center text-gray-600 dark:text-gray-500  text-xs mt-4">
        Already have an account? <%= link("Log in",
          to: "/login",
          class: "underline text-gray-800 dark:text-gray-50"
        ) %> instead.
      </p>
    </.form>
    """
  end

  defp name_input(assigns) do
    ~H"""
    <div class="my-4">
      <label for={@field.name} class="block text-sm font-medium text-gray-700 dark:text-gray-300">
        Full name
      </label>
      <div class="mt-1">
        <.input
          field={@field}
          placeholder="Jane Doe"
          class="dark:bg-gray-900 shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 dark:border-gray-500 rounded-md dark:text-gray-300"
        />
      </div>
    </div>
    """
  end

  defp email_input(assigns) do
    email_classes = ~w(
      bg-gray-100
      dark:bg-gray-900
      shadow-sm
      focus:ring-indigo-500
      focus:border-indigo-500
      block
      w-full
      sm:text-sm
      border-gray-300
      dark:border-gray-500
      rounded-md
      dark:text-gray-300
    )

    {email_readonly, email_extra_classes} =
      if assigns[:invitation_id] do
        {[readonly: "readonly"], ["bg-gray-100"]}
      else
        {[], []}
      end

    assigns =
      assigns
      |> assign(:email_readonly, email_readonly)
      |> assign(:email_classes, email_classes ++ email_extra_classes)

    ~H"""
    <div class="my-4">
      <div class="flex justify-between">
        <label for={@field.name} class="block text-sm font-medium text-gray-700 dark:text-gray-300">
          Email
        </label>
        <p class="text-xs text-gray-500 mt-1">No spam, guaranteed.</p>
      </div>
      <div class="mt-1">
        <.input
          type="email"
          field={@field}
          placeholder="example@email.com"
          class={@email_classes}
          {@email_readonly}
        />
      </div>
    </div>
    """
  end

  def handle_event("validate", %{"user" => params}, socket) do
    changeset =
      params
      |> Auth.User.new()
      |> Map.put(:action, :validate)

    password_strength = Auth.User.password_strength(changeset)

    {:noreply, assign(socket, form: to_form(changeset), password_strength: password_strength)}
  end

  def handle_event("register", %{"user" => _, "invitation_id" => invitation_id} = params, socket) do
    if not PlausibleWeb.Captcha.enabled?() or
         PlausibleWeb.Captcha.verify(params["h-captcha-response"]) do
      invitation = Repo.get_by(Auth.Invitation, invitation_id: invitation_id)

      user =
        params["user"]
        |> Map.put("email", invitation.email)
        |> Auth.User.new()

      user =
        case invitation.role do
          :owner -> user
          _ -> Plausible.Auth.User.remove_trial_expiry(user)
        end

      add_user(socket, user)
    else
      {:noreply, assign(socket, :captcha_error, "Please complete the captcha to register")}
    end
  end

  def handle_event("register", %{"user" => _} = params, socket) do
    if not PlausibleWeb.Captcha.enabled?() or
         PlausibleWeb.Captcha.verify(params["h-captcha-response"]) do
      user = Auth.User.new(params["user"])

      add_user(socket, user)
    else
      {:noreply, assign(socket, :captcha_error, "Please complete the captcha to register")}
    end
  end

  defp add_user(socket, user) do
    case Repo.insert(user) do
      {:ok, _user} ->
        {:noreply, assign(socket, trigger_submit: true)}

      {:error, changeset} ->
        {:noreply,
         assign(socket,
           form: to_form(Map.put(changeset, :action, :validate))
         )}
    end
  end
end
