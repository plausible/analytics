defmodule Plausible.Test.Support.HTML do
  @moduledoc """
  LazyHTML wrappers to help make assertions about HTML/DOM structures
  """

  def element_exists?(html, selector) do
    html
    |> find(selector)
    |> Enum.empty?()
    |> Kernel.not()
  end

  def find(html, selector) do
    html
    |> lazy_parse()
    |> LazyHTML.query(selector)
  end

  def submit_button(html, form) do
    find(html, "#{form} button[type=\"submit\"]")
  end

  def form_exists?(html, action_path) do
    element_exists?(html, "form[action=\"" <> action_path <> "\"]")
  end

  def text_of_element(html, selector) do
    html
    |> find(selector)
    |> text()
  end

  def elem_count(html, selector) do
    find(html, selector) |> Enum.count()
  end

  def text(element) do
    element
    |> lazy_parse()
    |> LazyHTML.text()
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
  end

  def attr_defined?(html, element, attr) do
    empty? =
      html
      |> find(element)
      |> LazyHTML.attribute(attr)
      |> Enum.empty?()

    not empty?
  end

  def class_of_element(html, element) do
    html
    |> find(element)
    |> text_of_attr("class")
  end

  def text_of_attr(html, selector, attr) do
    html
    |> find(selector)
    |> text_of_attr(attr)
  end

  def text_of_attr(element, attr) do
    case LazyHTML.attribute(lazy_parse(element), attr) do
      [] ->
        nil

      [value] ->
        value

      [_ | _] ->
        raise "Multiple attributes found. Narrow down the element you are looking for"
    end
  end

  def name_of(element) do
    text_of_attr(element, "name")
  end

  defp lazy_parse(%LazyHTML{} = lazy) do
    lazy
  end

  defp lazy_parse(element) when is_binary(element) do
    LazyHTML.from_fragment(element)
  end
end
