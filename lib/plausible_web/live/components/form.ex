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

  @default_input_class "text-sm text-gray-900 dark:text-white dark:bg-gray-900 block pl-3.5 py-2.5 border-gray-300 dark:border-gray-500 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 rounded-md"

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
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
         multiple pattern placeholder readonly required rows size step x-model)
  )

  attr(:class, :any, default: @default_input_class)

  attr(:mt?, :boolean, default: true)
  attr(:max_one_error, :boolean, default: false)
  slot(:help_content)
  slot(:inner_block)

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
    <div class={@mt? && "mt-2"}>
      <.label for={@id} class="mb-2">{@label}</.label>

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
    ~H"""
    <div class={[
      "flex flex-inline items-center sm:justify-start justify-center gap-x-2",
      @mt? && "mt-2"
    ]}>
      <input
        type="checkbox"
        value={@value || "true"}
        id={@id}
        name={@name}
        class="block h-5 w-5 rounded dark:bg-gray-700 border-gray-300 text-indigo-600 focus:ring-indigo-600"
      />
      <.label for={@id}>{@label}</.label>
    </div>
    """
  end

  def input(%{type: "radio"} = assigns) do
    input_class =
      if assigns.rest[:disabled] do
        "dark:bg-gray-500 bg-gray-200 border-gray-300"
      else
        "dark:bg-gray-700 border-gray-300"
      end

    label_class =
      if assigns.rest[:disabled] do
        "flex flex-col flex-inline dark:text-gray-300 text-gray-500"
      else
        "flex flex-col flex-inline"
      end

    assigns = assign(assigns, input_class: input_class, label_class: label_class)

    ~H"""
    <div class={[
      "flex flex-inline items-top justify-start gap-x-2",
      @mt? && "mt-2"
    ]}>
      <input
        type="radio"
        value={@value}
        id={@id}
        name={@name}
        checked={assigns[:checked]}
        class={["block h-5 w-5 text-indigo-600 focus:ring-indigo-600", @input_class]}
        {@rest}
      />
      <.label class={@label_class} for={@id}>
        <span>{@label}</span>

        <span
          :if={@help_text || @help_content != []}
          class="text-gray-500 dark:text-gray-400 mb-2 text-sm"
        >
          {@help_text}
          {render_slot(@help_content)}
        </span>
      </.label>
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
    <div class={@mt? && "mt-2"}>
      <.label :if={@label != nil and @label != ""} for={@id} class="mb-2">
        {@label}
      </.label>
      <p :if={@help_text} class="text-gray-500 dark:text-gray-400 mb-2 text-sm">
        {@help_text}
      </p>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[@class, @width, assigns[:rest][:disabled] && "text-gray-500 dark:text-gray-400"]}
        {@rest}
      />
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
          class="absolute flex items-center text-xs font-medium text-indigo-600 no-underline hover:underline top-3 right-4"
        >
          <Heroicons.document_duplicate class="pr-1 text-indigo-600 dark:text-indigo-500 w-5 h-5" />
          <span>
            COPY
          </span>
        </a>
      </div>
    </div>
    """
  end

  attr(:id, :any, default: nil)
  attr(:label, :string, default: nil)

  attr(:field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:password]",
    required: true
  )

  attr(:strength, :any)

  attr(:rest, :global,
    include: ~w(autocomplete disabled form maxlength minlength readonly required size)
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
    <.input field={@field} type="password" autocomplete="new-password" label={@label} id={@id} {@rest}>
      <.strength_meter :if={@show_meter?} {@strength} />
    </.input>
    """
  end

  attr(:minimum, :integer, required: true)

  attr(:class, :any)
  attr(:ok_class, :any)
  attr(:error_class, :any)

  attr(:field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:password]",
    required: true
  )

  def password_length_hint(%{field: field} = assigns) do
    {strength_errors, _} = pop_strength_errors(field.errors)

    ok_class = assigns[:ok_class] || "text-gray-500"
    error_class = assigns[:error_class] || "text-red-500"
    class = assigns[:class] || ["text-xs", "mt-1"]

    color =
      if :length in strength_errors do
        error_class
      else
        ok_class
      end

    final_class = [color | class]

    assigns = assign(assigns, :class, final_class)

    ~H"""
    <p class={@class}>Min {@minimum} characters</p>
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
    color =
      cond do
        assigns.score <= 1 -> ["bg-red-500", "dark:bg-red-500"]
        assigns.score == 2 -> ["bg-red-300", "dark:bg-red-300"]
        assigns.score == 3 -> ["bg-indigo-300", "dark:bg-indigo-300"]
        assigns.score >= 4 -> ["bg-indigo-600", "dark:bg-indigo-500"]
      end

    feedback =
      cond do
        assigns.warning != "" -> assigns.warning <> "."
        assigns.suggestions != [] -> List.first(assigns.suggestions)
        true -> nil
      end

    assigns =
      assigns
      |> assign(:color, color)
      |> assign(:feedback, feedback)

    ~H"""
    <div class="w-full bg-gray-200 rounded-full h-1.5 mb-2 mt-2 dark:bg-gray-700 mt-1">
      <div
        class={["h-1.5", "rounded-full"] ++ @color}
        style={["width: " <> to_string(@score * 25) <> "%"]}
      >
      </div>
    </div>
    <p :if={@score <= 2} class="text-sm text-red-500">
      Password is too weak
    </p>
    <p :if={@feedback} class="text-xs text-gray-500">
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
    <p class="flex gap-3 text-sm leading-6 text-red-500">
      {render_slot(@inner_block)}
    </p>
    """
  end

  def translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end

  attr :conn, Plug.Conn, required: true
  attr :name, :string, required: true
  attr :options, :list, required: true
  attr :value, :any, default: nil
  attr :href_base, :string, default: "/"
  attr :selected_fn, :any, required: true

  def mobile_nav_dropdown(%{options: options} = assigns) do
    options =
      Enum.reduce(options, Map.new(), fn
        {section, opts}, acc when is_list(opts) ->
          Map.put(acc, section, for(o <- opts, do: {o.key, o.value}))

        {key, value}, _acc when is_binary(key) and is_binary(value) ->
          options
      end)

    assigns = assign(assigns, :options, options)

    ~H"""
    <.form for={@conn} class="lg:hidden py-4">
      <.input
        value={
          @options
          |> Enum.flat_map(fn
            {_section, opts} when is_list(opts) -> opts
            {k, v} when is_binary(k) and is_binary(v) -> [{k, v}]
          end)
          |> Enum.find_value(fn {_k, v} ->
            apply(@selected_fn, [v]) && v
          end)
        }
        name={@name}
        type="select"
        options={@options}
        onchange={"if (event.target.value) { location.href = '#{@href_base}' + event.target.value }"}
        class="dark:bg-gray-800 mt-1 block w-full pl-3.5 pr-10 py-2.5 text-base border-gray-300 dark:border-gray-500 outline-none focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 rounded-md dark:text-gray-100"
      />
    </.form>
    """
  end
end
