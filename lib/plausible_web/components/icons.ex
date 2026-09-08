defmodule PlausibleWeb.Components.Icons do
  @moduledoc """
  Reusable icon components
  """
  use Phoenix.Component

  attr(:rest, :global)
  attr(:filled, :boolean, default: false)

  def pin_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill={if @filled, do: "currentColor", else: "none"}
      stroke="currentColor"
      stroke-linecap="round"
      stroke-linejoin="round"
      stroke-width="1.5"
      {@rest}
    >
      <path d="m4 20 4.5-4.5-.196.196M14.314 21.005l-5.657-5.657L3 9.69l1.228-1.228a3 3 0 0 1 3.579-.501l.58.322 7.34-5.664 5.658 5.657-5.665 7.34.323.581a3 3 0 0 1-.501 3.578l-1.228 1.229Z" />
    </svg>
    """
  end

  attr :class, :any, default: []

  def external_link_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
      class={@class}
    >
      <path
        stroke="currentColor"
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="1.5"
        d="M9 5H5a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-4M12 12l9-9-.303.303M14 3h7v7"
      />
    </svg>
    """
  end

  attr :class, :any, default: []

  def tag_icon(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class={@class}>
      <path fill="currentColor" d="M8.7 10.2a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3" />
      <path
        stroke="currentColor"
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="1.5"
        d="M4.8 3.602h6.206a2.4 2.4 0 0 1 1.697.703l6.643 6.643a3.597 3.597 0 0 1 0 5.092l-3.308 3.308a3.6 3.6 0 0 1-5.092 0l-6.643-6.643a2.4 2.4 0 0 1-.703-1.697V4.802a1.2 1.2 0 0 1 1.2-1.2"
      />
    </svg>
    """
  end

  attr :class, :any, default: []

  def diamond_icon(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class={@class}>
      <path
        stroke="currentColor"
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="1.5"
        d="M2.734 9h18.531M3.023 8.164l3.205-3.408c.255-.27.61-.424.984-.424h9.57c.374 0 .73.153.985.424l3.205 3.408c.44.468.48 1.18.093 1.693l-7.99 10.608a1.352 1.352 0 0 1-2.155 0L2.93 9.857a1.31 1.31 0 0 1 .093-1.693"
      />
    </svg>
    """
  end

  attr :class, :any, default: []

  def subscription_icon(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class={@class}>
      <path
        stroke="currentColor"
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="1.5"
        d="m21.667 4.333-.72 4a9.669 9.669 0 0 0-18.61 3.399m-.004 7.934.72-4a9.67 9.67 0 0 0 18.61-3.4"
      />
      <path
        stroke="currentColor"
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="1.5"
        d="M14.333 8.333h-3.166a1.835 1.835 0 0 0-1.834 1.827c0 1.013.82 1.84 1.834 1.84h1.666c1.012 0 1.834.827 1.834 1.827 0 1.013-.822 1.84-1.834 1.84H9.667M12 7v1.333M12 17v-1.333"
      />
    </svg>
    """
  end

  attr :class, :any, default: []

  def key_icon(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class={@class}>
      <g
        fill="currentColor"
        stroke="currentColor"
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="1.5"
        transform="translate(.25 .25)"
      >
        <circle cx="8" cy="16" r="1" />
        <path
          fill="none"
          d="M17 2 9.856 9.144A6.5 6.5 0 1 0 15 15.5a6.47 6.47 0 0 0-.366-2.134L17 11V8h3l2-2V2h-5Z"
        />
      </g>
    </svg>
    """
  end

  attr :class, :any, default: []

  def exclamation_triangle_icon(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class={@class}>
      <g fill="currentColor" stroke-linecap="round" stroke-linejoin="round">
        <circle
          cx="12"
          cy="12"
          r="10"
          fill="none"
          stroke="currentColor"
          stroke-miterlimit="10"
          stroke-width="1.5"
        />
        <path
          fill="none"
          stroke="currentColor"
          stroke-miterlimit="10"
          stroke-width="1.5"
          d="M12 7v6"
        />
        <circle cx="12" cy="16.75" r="1.25" />
      </g>
    </svg>
    """
  end

  attr :class, :any, default: []

  def copy_icon(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 18 18" class={@class}>
      <g
        fill="none"
        stroke="currentColor"
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="1.5"
      >
        <path d="M2.25 6.75v6.5a2 2 0 0 0 2 2h7.5" />
        <path d="M7.25 12.25h6.5a2 2 0 0 0 2-2v-5.5a2 2 0 0 0-2-2h-6.5a2 2 0 0 0-2 2v5.5a2 2 0 0 0 2 2" />
      </g>
    </svg>
    """
  end

  attr :class, :any, default: []

  def pencil_icon(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class={@class}>
      <path
        stroke="currentColor"
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="1.5"
        d="m14.063 5.897 4.041 4.041M3.667 20.334s4.799-.757 6.061-2.02l9.77-9.77a2.857 2.857 0 0 0-4.04-4.04l-9.77 9.77c-1.262 1.263-2.02 6.061-2.02 6.061z"
      />
    </svg>
    """
  end

  attr :class, :any, default: []

  def button_click_icon(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class={@class}>
      <path
        stroke="currentColor"
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="1.5"
        d="M21.666 11.178V7.667A2.667 2.667 0 0 0 19 5H5a2.667 2.667 0 0 0-2.667 2.667v4.666A2.667 2.667 0 0 0 5 15h4.197"
      />
      <path
        stroke="currentColor"
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="1.5"
        d="m13.245 12.359 9.139 3.339a.43.43 0 0 1-.016.814l-4.183 1.339-1.339 4.183a.43.43 0 0 1-.814.016l-3.339-9.139a.43.43 0 0 1 .552-.552"
      />
    </svg>
    """
  end

  attr :class, :any, default: []

  def error_page_icon(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class={@class}>
      <path
        stroke="currentColor"
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="1.5"
        d="M5.519 10.947c-2.482 2.041-3.839 3.923-3.296 4.864.829 1.435 5.765.135 11.026-2.902s8.855-6.663 8.027-8.098c-.543-.94-2.852-.707-5.86.422"
      />
      <path
        stroke="currentColor"
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="1.5"
        d="M8.25 4.25a6 6 0 0 1 8.196 2.196l-.215.243a18 18 0 0 1-9.86 5.692l-.317.065A6 6 0 0 1 8.25 4.25M18.75 21.75l-3-5M22.75 14.25l-2.5-1M10.25 19.25v3"
      />
    </svg>
    """
  end

  attr :class, :any, default: []

  def envelope_icon(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class={@class}>
      <path
        stroke="currentColor"
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="1.5"
        d="M2.333 9c0-.97.528-1.814 1.38-2.284L11.355 2.5a1.332 1.332 0 0 1 1.288 0l7.644 4.217c.85.47 1.379 1.312 1.379 2.284"
      />
      <path
        stroke="currentColor"
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="1.5"
        d="M21.667 9.005v8.662A2.666 2.666 0 0 1 19 20.333H5a2.666 2.666 0 0 1-2.667-2.666V9l9.087 4.387c.367.177.793.177 1.159 0L21.666 9v.005Z"
      />
    </svg>
    """
  end
end
