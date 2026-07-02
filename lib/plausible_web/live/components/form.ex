defmodule PlausibleWeb.Live.Components.Form do
  @moduledoc """
  Generic components stolen from mix phx.new templates
  """

  use Phoenix.Component

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Examples

  <.input field={@form[:email]} type="email" />
  <.input name="my-input" errors={["oh no!"]} />
  """

  @default_input_class "text-sm text-gray-900 dark:text-white dark:bg-gray-750 block pl-3.5 py-2.5 border-gray-300 dark:border-gray-800 transition-all duration-150 focus:outline-none focus:ring-3 focus:ring-indigo-500/20 dark:focus:ring-indigo-500/25 focus:border-indigo-500 rounded-md disabled:bg-gray-100 disabled:dark:bg-gray-800 disabled:border-gray-200 disabled:dark:border-gray-800 disabled:text-gray-900/40 disabled:dark:text-white/30 disabled:cursor-not-allowed"

  attr(:id, :any, default: nil)
  attr(:name, :any)
  attr(:label, :string, default: nil)
  attr(:help_text, :string, default: nil)
  attr(:value, :any)
  attr(:width, :string, default: "w-full")

  attr(:type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file hidden month number password
         range radio search select tel text textarea time url week)
  )

  attr(:field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"
  )

  attr(:errors, :list, default: [])
  attr(:checked, :boolean, doc: "the checked flag for checkbox inputs")
  attr(:prompt, :string, default: nil, doc: "the prompt for select inputs")
  attr(:options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2")
  attr(:multiple, :boolean, default: false, doc: "the multiple flag for select inputs")

  attr(:rest, :global,
    include:
      ~w(accept autocomplete autofocus capture cols disabled form list max maxlength min minlength
         multiple pattern placeholder readonly required rows size step x-bind:type x-model)
  )

  attr(:class, :any, default: @default_input_class)

  attr(:mt?, :boolean, default: true)
  attr(:max_one_error, :boolean, default: false)
  slot(:help_content)
  slot(:inner_block)
  slot(:trailing)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(
      field: nil,
      id: assigns.id || field.id,
      class: assigns.class,
      mt?: assigns.mt?,
      width: assigns.width
    )
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class={@mt? && "mt-6"}>
      <.label
        :if={@label != nil and @label != ""}
        for={@id}
        class={if @help_text, do: "mb-0.5", else: "mb-1.5"}
      >
        {@label}
      </.label>

      <p :if={@help_text} class="text-gray-500 dark:text-gray-400 mb-2 text-sm">
        {@help_text}
      </p>
      <select id={@id} name={@name} multiple={@multiple} class={[@class, @width]} {@rest}>
        <option :if={@prompt} value="">{@prompt}</option>
        {Phoenix.HTML.Form.options_for_select(@options, @value)}
      </select>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class={[
      @mt? && "mt-2"
    ]}>
      <.label
        for={@id}
        class="font-normal gap-x-2 flex flex-inline items-center sm:justify-start justify-center "
      >
        <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} />
        <input
          type="checkbox"
          value="true"
          checked={@checked}
          id={@id}
          name={@name}
          class="block size-5 rounded-sm dark:bg-gray-600 border-gray-300 dark:border-gray-600 text-indigo-600"
          {@rest}
        />
        {@label}
      </.label>
    </div>
    """
  end

  def input(%{type: "radio"} = assigns) do
    ~H"""
    <div class={[
      "flex flex-inline justify-start gap-x-3"
    ]}>
      <input
        type="radio"
        value={@value}
        id={@id}
        name={@name}
        checked={assigns[:checked]}
        class="block dark:bg-gray-900 size-4.5 mt-px cursor-pointer text-indigo-600 border-gray-400 dark:border-gray-600 checked:border-indigo-600 dark:checked:border-white disabled:cursor-not-allowed"
        {@rest}
      />
      <.label :if={@label} class="flex flex-col flex-inline" for={@id}>
        <span>{@label}</span>

        <span
          :if={@help_text || @help_content != []}
          class="text-gray-500 dark:text-gray-400 mb-2 text-sm text-pretty"
        >
          {@help_text}
          {render_slot(@help_content)}
        </span>
      </.label>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class={@mt? && "mt-6"}>
      <.label class="mb-1.5" for={@id}>{@label}</.label>
      <textarea
        id={@id}
        rows={@rest[:rows] || "6"}
        name={@name}
        class="block w-full textarea border-1 border-gray-300 rounded-md p-4 text-sm text-gray-700 dark:border-gray-500 dark:bg-gray-900 dark:text-gray-300"
        {@rest}
      >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    errors =
      if assigns.max_one_error do
        Enum.take(assigns.errors, 1)
      else
        assigns.errors
      end

    assigns = assign(assigns, :errors, errors)

    ~H"""
    <div class={@mt? && "mt-6"}>
      <.label
        :if={@label != nil and @label != ""}
        for={@id}
        class={if @help_text, do: "mb-0.5", else: "mb-1.5"}
      >
        {@label}
      </.label>
      <p :if={@help_text} class="text-gray-500 dark:text-gray-400 mb-2 text-sm">
        {@help_text}
      </p>
      <div class="relative">
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={[@class, @width, assigns[:rest][:disabled] && "text-gray-500 dark:text-gray-400"]}
          {@rest}
        />
        {render_slot(@trailing)}
      </div>
      {render_slot(@inner_block)}
      <.error :for={msg <- @errors}>
        {msg}
      </.error>
    </div>
    """
  end

  attr(:rest, :global)
  attr(:id, :string, required: true)
  attr(:name, :string, required: true)
  attr(:label, :string, default: nil)
  attr(:value, :string, default: "")

  def input_with_clipboard(assigns) do
    class = [@default_input_class, "pr-20 w-full"]
    assigns = assign(assigns, class: class)

    ~H"""
    <div>
      <div :if={@label}>
        <.label for={@id} class="mb-2">
          {@label}
        </.label>
      </div>
      <div class="relative">
        <.input
          mt?={false}
          id={@id}
          name={@name}
          value={@value}
          type="text"
          readonly="readonly"
          class={@class}
          {@rest}
        />
        <a
          onclick={"var input = document.getElementById('#{@id}'); input.focus(); input.select(); document.execCommand('copy'); event.stopPropagation();"}
          href="javascript:void(0)"
          class="absolute flex items-center text-xs font-medium text-indigo-600 dark:text-indigo-500 no-underline hover:text-indigo-700 dark:hover:text-indigo-400 top-3 right-4 transition-colors duration-150"
        >
          <Heroicons.document_duplicate class="mr-1 size-4" />
          <span>
            COPY
          </span>
        </a>
      </div>
    </div>
    """
  end

  @doc """
  Renders a password input with a show/hide reveal toggle.
  """
  attr(:id, :any, default: nil)
  attr(:label, :string, default: nil)
  attr(:mt?, :boolean, default: true)
  attr(:autocomplete, :string, default: "current-password")

  attr(:field, Phoenix.HTML.FormField, required: true)

  attr(:rest, :global,
    include:
      ~w(autocomplete autofocus disabled form maxlength minlength placeholder readonly required size)
  )

  slot(:inner_block)

  def password_field(assigns) do
    assigns = assign(assigns, :class, [@default_input_class, "pr-10"])

    ~H"""
    <div x-data="{ showPassword: false }">
      <.input
        type="password"
        x-bind:type="showPassword ? 'text' : 'password'"
        field={@field}
        label={@label}
        id={@id}
        autocomplete={@autocomplete}
        mt?={@mt?}
        class={@class}
        {@rest}
      >
        <:trailing>
          <button
            type="button"
            @click="showPassword = !showPassword"
            tabindex="-1"
            aria-label="Toggle password visibility"
            class="absolute inset-y-0 right-2 flex items-center text-gray-500 hover:text-gray-600 dark:text-gray-400 dark:hover:text-gray-300 transition-colors duration-150"
          >
            <span x-show="!showPassword">
              <Heroicons.eye class="size-4" />
            </span>
            <span x-show="showPassword" x-cloak>
              <Heroicons.eye_slash class="size-4" />
            </span>
          </button>
        </:trailing>
        {render_slot(@inner_block)}
      </.input>
    </div>
    """
  end

  @doc """
  Renders a one-time-code input (activation code, 2FA code, etc.).
  """
  attr(:field, Phoenix.HTML.FormField, required: true)
  attr(:length, :integer, default: 6)

  attr(:autosubmit?, :boolean, default: false)

  attr(:rest, :global, include: ~w(autofocus oninvalid))

  def otp_input(assigns) do
    oninput_js =
      "this.value=this.value.replace(/[^0-9]/g, '');" <>
        if assigns.autosubmit? do
          " if (this.value.length >= #{assigns.length}) this.form.requestSubmit();"
        else
          ""
        end

    input_class = [
      @default_input_class,
      "font-mono tracking-[0.5em] font-medium text-center w-full"
    ]

    assigns =
      assigns
      |> assign(:input_class, input_class)
      |> assign(:placeholder, String.duplicate("•", assigns.length))
      |> assign(:oninput_js, oninput_js)

    ~H"""
    <input
      type="text"
      id={@field.id}
      name={@field.name}
      value={@field.value}
      class={@input_class}
      inputmode="numeric"
      autocomplete="one-time-code"
      pattern="[0-9]*"
      maxlength={@length}
      placeholder={@placeholder}
      required
      onclick="this.select();"
      oninput={@oninput_js}
      {@rest}
    />
    """
  end

  attr(:id, :any, default: nil)
  attr(:label, :string, default: nil)
  attr(:mt?, :boolean, default: true)

  attr(:field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:password]",
    required: true
  )

  attr(:strength, :any)

  attr(:rest, :global,
    include:
      ~w(autocomplete autofocus disabled form maxlength minlength placeholder readonly required size)
  )

  def password_input_with_strength(%{field: field} = assigns) do
    {too_weak?, errors} =
      case pop_strength_errors(field.errors) do
        {strength_errors, other_errors} when strength_errors != [] ->
          {true, other_errors}

        {[], other_errors} ->
          {false, other_errors}
      end

    strength =
      if too_weak? and assigns.strength.score >= 3 do
        %{assigns.strength | score: 2}
      else
        assigns.strength
      end

    assigns =
      assigns
      |> assign(:too_weak?, too_weak?)
      |> assign(:field, %{field | errors: errors})
      |> assign(:strength, strength)
      |> assign(
        :show_meter?,
        Phoenix.Component.used_input?(field) && (too_weak? || strength.score > 0)
      )

    ~H"""
    <.password_field
      field={@field}
      autocomplete="new-password"
      label={@label}
      id={@id}
      mt?={@mt?}
      {@rest}
    >
      <.strength_meter :if={@show_meter?} {@strength} />
    </.password_field>
    """
  end

  attr(:minimum, :integer, required: true)

  attr(:class, :any)
  attr(:ok_class, :any)
  attr(:error_class, :any)
  attr(:hide_when_used?, :boolean, default: false)

  attr(:field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:password]",
    required: true
  )

  def password_length_hint(%{field: field} = assigns) do
    {strength_errors, _} = pop_strength_errors(field.errors)

    hidden? = assigns.hide_when_used? and Phoenix.Component.used_input?(field)

    ok_class = assigns[:ok_class] || "text-gray-500 dark:text-gray-400"
    error_class = assigns[:error_class] || "text-red-500 dark:text-red-400"
    class = assigns[:class] || ["text-xs"]

    color =
      if :length in strength_errors do
        error_class
      else
        ok_class
      end

    final_class = [color | class]

    assigns =
      assigns
      |> assign(:class, final_class)
      |> assign(:hidden?, hidden?)

    ~H"""
    <p :if={not @hidden?} class={@class}>At least {@minimum} characters</p>
    """
  end

  defp pop_strength_errors(errors) do
    Enum.reduce(errors, {[], []}, fn {_, meta} = error, {detected, other_errors} ->
      cond do
        meta[:validation] == :required ->
          {[:required | detected], other_errors}

        meta[:validation] == :length and meta[:kind] == :min ->
          {[:length | detected], other_errors}

        meta[:validation] == :strength ->
          {[:strength | detected], other_errors}

        true ->
          {detected, [error | other_errors]}
      end
    end)
  end

  attr(:score, :integer, default: 0)
  attr(:warning, :string, default: "")
  attr(:suggestions, :list, default: [])

  def strength_meter(assigns) do
    feedback =
      cond do
        assigns.warning != "" -> assigns.warning <> "."
        assigns.suggestions != [] -> List.first(assigns.suggestions)
        true -> nil
      end

    strength_label =
      cond do
        assigns.score == 3 -> "Good"
        assigns.score >= 4 -> "Strong"
        true -> nil
      end

    assigns =
      assigns
      |> assign(:feedback, feedback)
      |> assign(:strength_label, strength_label)

    ~H"""
    <p :if={@score <= 2} class="text-xs text-red-500 mt-2">
      Password is too weak.
    </p>
    <p :if={@strength_label} class="text-xs mt-2">
      <span class="text-gray-500 dark:text-gray-400">Password strength:</span>
      <span class="text-green-600 dark:text-green-500 font-medium">{@strength_label}</span>
    </p>
    <p :if={@feedback && @score <= 2} class="text-xs text-gray-500 dark:text-gray-400">
      {@feedback}
    </p>
    """
  end

  @doc """
  Renders a label.
  """
  attr :for, :string, default: nil
  slot :inner_block, required: true
  attr :class, :string, default: ""

  def label(assigns) do
    ~H"""
    <label for={@for} class={["text-sm block font-medium dark:text-gray-100", @class]}>
      {render_slot(@inner_block)}
    </label>
    """
  end

  @doc """
  Generates a generic error message.
  """
  slot(:inner_block, required: true)

  def error(assigns) do
    ~H"""
    <p class="mt-1 flex gap-3 text-xs text-red-500 leading-4.5 text-pretty">
      {render_slot(@inner_block)}
    </p>
    """
  end

  def translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end

  attr :conn, :map, default: %{}
  attr :name, :string, required: true
  attr :options, :list, required: true
  attr :value, :any, default: nil
  attr :href_base, :string, default: "/"
  attr :selected_fn, :any, required: true

  def mobile_nav_dropdown(%{options: options} = assigns) do
    assigns = assign(assigns, :options, flatten_options(options))

    ~H"""
    <.form for={@conn} class="lg:hidden py-4" data-testid="mobile-nav-dropdown">
      <.input
        value={
          @options
          |> Enum.find_value(fn {_k, v} ->
            apply(@selected_fn, [v]) && v
          end)
        }
        name={@name}
        type="select"
        options={@options}
        onchange={"if (event.target.value) { location.href = '#{@href_base}' + event.target.value }"}
        class="dark:bg-gray-800 mt-1 block w-full pl-3.5 pr-10 py-2.5 text-base border-gray-300 dark:border-gray-500 outline-hidden focus:outline-hidden focus:ring-indigo-500 focus:border-indigo-500 rounded-md dark:text-gray-100"
      />
    </.form>
    """
  end

  defp flatten_options(options, prefix \\ "") do
    options
    |> Enum.map(fn
      {key, suboptions} when is_list(suboptions) ->
        flatten_options(suboptions, prefix <> key <> ": ")

      {key, value} when is_binary(value) ->
        {prefix <> key, value}

      %{value: value, key: key} when is_binary(value) ->
        {prefix <> key, value}

      %{value: submenu_items, key: parent_key} when is_list(submenu_items) ->
        Enum.map(submenu_items, fn submenu_item ->
          {"#{prefix}#{parent_key}: #{submenu_item.key}", submenu_item.value}
        end)
    end)
    |> List.flatten()
  end
end
