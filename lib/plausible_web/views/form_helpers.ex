defmodule PlausibleWeb.FormHelpers do
  @label_opts [class: "block text-sm font-medium text-gray-700 dark:text-gray-100"]
  def styled_label(form, field, text, opts \\ []) do
    opts = Keyword.merge(@label_opts, opts)
    Phoenix.HTML.Form.label(form, field, text, opts)
  end

  @text_input_opts [
    class:
      "mt-1 block w-full px-3 py-2 text-base dark:text-gray-100 dark:border-gray-500 border-gray-300 focus:outline-none sm:text-sm rounded-md"
  ]
  @active_text_input_class "dark:bg-gray-900 focus:ring-indigo-500 focus:border-indigo-500"
  @disabled_text_input_class "bg-gray-100 dark:bg-gray-800 select-none cursor-default"
  def styled_text_input(form, field, opts \\ []) do
    opts = merge_opts(@text_input_opts, opts)

    extra_class =
      if opts[:readonly] == "true", do: @disabled_text_input_class, else: @active_text_input_class

    opts = merge_opts(opts, class: extra_class)

    Phoenix.HTML.Form.text_input(form, field, opts)
  end

  @select_opts [
    class:
      "mt-1 block w-full pl-3 pr-10 py-2 text-base dark:text-gray-100 dark:border-gray-500 border-gray-300 focus:outline-none sm:text-sm rounded-md"
  ]
  @active_select_class "dark:bg-gray-900 focus:ring-indigo-500 focus:border-indigo-500"
  @disabled_select_class "bg-gray-100 dark:bg-gray-800 select-none"
  def styled_select(form, field, options, opts \\ []) do
    opts = merge_opts(@select_opts, opts)

    extra_class =
      if opts[:disabled] == "true", do: @disabled_select_class, else: @active_select_class

    opts = merge_opts(opts, class: extra_class)
    Phoenix.HTML.Form.select(form, field, options, opts)
  end

  @error_opts [class: "mt-1 block text-sm font-medium text-red-700 dark:text-red-500"]
  def styled_error(nil), do: nil

  def styled_error(error) when is_binary(error) do
    Phoenix.HTML.Tag.content_tag(:p, error, @error_opts)
  end

  defp merge_opts(opts1, opts2) do
    Keyword.merge(opts1, opts2, fn
      :class, v1, v2 -> v1 <> " " <> v2
      _k, _v1, v2 -> v2
    end)
  end
end
