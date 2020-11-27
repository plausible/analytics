defmodule PlausibleWeb.ErrorHelpers do
  use Phoenix.HTML

  def error_tag(form, field) do
    Enum.map(Keyword.get_values(form.errors, field), fn error ->
      content_tag(:div, elem(error, 0), class: "mt-2 text-sm text-red-600")
    end)
  end
end
