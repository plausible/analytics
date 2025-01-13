defmodule Plausible.Test.Support.HTML do
  Code.ensure_compiled!(Floki)

  @moduledoc """
  Floki wrappers to help make assertions about HTML/DOM structures
  """

  def element_exists?(html, selector) do
    html
    |> find(selector)
    |> Enum.empty?()
    |> Kernel.not()
  end

  def find(html, value) when is_binary(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find(value)
  end

  def find(html, value) do
    Floki.find(html, value)
  end

  def submit_button(html, form) do
    find(html, "#{form} button[type=\"submit\"]")
  end

  def form_exists?(html, action_path) do
    element_exists?(html, "form[action=\"" <> action_path <> "\"]")
  end

  def text_of_element(html, element) do
    html
    |> find(element)
    |> Floki.text()
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
  end

  def text(element) do
    element
    |> Floki.text()
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
  end

  def class_of_element(html, element) do
    html
    |> find(element)
    |> text_of_attr("class")
  end

  def text_of_attr(html, element, attr) do
    html
    |> find(element)
    |> text_of_attr(attr)
  end

  def text_of_attr(element, attr) do
    element
    |> Floki.attribute(attr)
    |> Floki.text()
    |> String.trim()
  end

  def name_of(element) do
    List.first(Floki.attribute(element, "name"))
  end
end
