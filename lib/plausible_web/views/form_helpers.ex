defmodule PlausibleWeb.FormHelpers do
  @label_opts [class: "block text-sm font-medium text-gray-700 dark:text-gray-100"]
  def styled_label(form, field, text, opts \\ []) do
    opts = Keyword.merge(@label_opts, opts)
    Phoenix.HTML.Form.label(form, field, text, opts)
  end

  @date_input_opts [
    class:
      "mt-1 block w-full px-3 py-2 text-base dark:bg-gray-900 dark:text-gray-300 dark:border-gray-500 border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md"
  ]
  def styled_date_input(form, field, opts \\ []) do
    opts = Keyword.merge(@date_input_opts, opts)
    Phoenix.HTML.Form.date_input(form, field, opts)
  end

  @select_opts [
    class:
      "mt-1 block w-full pl-3 pr-10 py-2 text-base dark:bg-gray-900 dark:text-gray-100 dark:border-gray-500 border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md"
  ]

  def styled_select(form, field, options, opts \\ []) do
    opts = Keyword.merge(@select_opts, opts)
    Phoenix.HTML.Form.select(form, field, options, opts)
  end
end
