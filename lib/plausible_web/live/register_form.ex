defmodule PlausibleWeb.Live.RegisterForm do
  @moduledoc """
  LiveView for registration form.
  """

  use Phoenix.LiveView
  use Phoenix.HTML

  import PlausibleWeb.Live.Components.Form

  alias Plausible.Auth

  def mount(_params, %{"is_selfhost" => is_selfhost}, socket) do
    changeset = Auth.User.changeset(%Auth.User{})

    {:ok,
     assign(socket,
       form: to_form(changeset),
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
      <input name="_csrf_token" type="hidden" value={Plug.CSRFProtection.get_csrf_token()}>

      <h2 class="text-xl font-black dark:text-gray-100">Enter your details</h2>

      <div class="my-4">
        <label for={f[:name].name} class="block text-sm font-medium text-gray-700 dark:text-gray-300">
          Full name
        </label>
        <div class="mt-1">
          <.input
            field={f[:name]}
            placeholder="Jane Doe"
            class="dark:bg-gray-900 shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 dark:border-gray-500 rounded-md dark:text-gray-300"
          />
        </div>
      </div>

      <div class="my-4">
        <div class="flex justify-between">
          <label
            for={f[:email].name}
            class="block text-sm font-medium text-gray-700 dark:text-gray-300"
          >
            Email
          </label>
          <p class="text-xs text-gray-500 mt-1">No spam, guaranteed.</p>
        </div>
        <div class="mt-1">
          <.input
            type="email"
            field={f[:email]}
            placeholder="example@email.com"
            class="dark:bg-gray-900 shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 dark:border-gray-500 rounded-md dark:text-gray-300"
          />
        </div>
      </div>

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
          <div class="h-captcha" data-sitekey={PlausibleWeb.Captcha.sitekey()}></div>
          <%= if assigns[:captcha_error] do %>
            <div class="text-red-500 text-xs italic mt-3"><%= @captcha_error %></div>
          <% end %>
          <script src="https://hcaptcha.com/1/api.js" async defer>
          </script>
        </div>
      <% end %>

      <% submit_text =
        if @is_selfhost do
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

  def handle_event("validate", %{"user" => params}, socket) do
    changeset =
      params
      |> Auth.User.new()
      |> Map.put(:action, :validate)

    password_strength = Auth.User.password_strength(changeset)

    {:noreply, assign(socket, form: to_form(changeset), password_strength: password_strength)}
  end

  def handle_event("register", %{"user" => params}, socket) do
    user = Plausible.Auth.User.new(params)

    case Plausible.Repo.insert(user) do
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
