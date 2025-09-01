defmodule PlausibleWeb.Live.PlainCombo do
  @moduledoc """
  Plain ComboBox live view wrapper, suitable for drop-in
  select element replacement, embeddable in dead views.
  """
  use PlausibleWeb, :live_view

  alias PlausibleWeb.Live.Components.ComboBox

  def mount(
        _params,
        %{
          "options" => options,
          "prompt" => prompt,
          "name" => name,
          "id" => id,
          "selected" => selected
        },
        socket
      ) do
    socket =
      assign(socket,
        options: options,
        id: id,
        prompt: prompt,
        submit_name: name,
        selected: selected
      )

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.live_component
        id={@id}
        submit_name={@submit_name}
        selected={@selected}
        module={ComboBox}
        placeholder={@prompt}
        suggest_fun={&ComboBox.StaticSearch.suggest/2}
        options={@options}
      />
    </div>
    """
  end
end
