defmodule PlausibleWeb.Components.Icons do
  @moduledoc """
  Reusable icon components
  """
  use Phoenix.Component

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
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" class={@class}>
      <circle fill="currentColor" cx="7.25" cy="7.25" r="1.25" />
      <path
        fill="none"
        stroke="currentColor"
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="1.5"
        d="M4 3h5.172a2 2 0 0 1 1.414.586l5.536 5.536a3 3 0 0 1 0 4.243l-2.757 2.757a3 3 0 0 1-4.243 0l-5.536-5.536A2 2 0 0 1 3 9.172V4a1 1 0 0 1 1-1Z"
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
