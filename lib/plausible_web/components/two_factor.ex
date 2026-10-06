defmodule PlausibleWeb.Components.TwoFactor do
  @moduledoc """
  Reusable components specific to 2FA
  """
  use PlausibleWeb, :component

  attr :text, :string, required: true
  attr :scale, :integer, default: 4

  def qr_code(assigns) do
    qr_code =
      assigns.text
      |> EQRCode.encode()
      |> EQRCode.svg(%{width: 160})

    assigns = assign(assigns, :code, qr_code)

    ~H"""
    {Phoenix.HTML.raw(@code)}
    """
  end

  attr :id, :string, default: "verify-button"
  attr :form, :any, required: true
  attr :field, :any, required: true
  attr :class, :string, default: ""
  attr :show_button?, :boolean, default: true
  attr :autofocus?, :boolean, default: false
  attr :error, :string, default: nil

  def verify_2fa_input(assigns) do
    assigns = assign(assigns, :field, assigns[:form][assigns[:field]])

    ~H"""
    <div class={[@class, "flex flex-col gap-y-6 items-center"]}>
      <div class="flex flex-col gap-y-2 w-full">
        <.otp_input
          field={@field}
          length={6}
          oninvalid={@show_button? && "document.getElementById('#{@id}').disabled = false"}
          autofocus={@autofocus? && "autofocus"}
        />
        <p :if={@error} class="text-xs text-red-500 text-center">
          {@error}
        </p>
      </div>
      <.button
        :if={@show_button?}
        type="submit"
        id={@id}
        class="w-full [&>span.label-enabled]:block [&>span.label-disabled]:hidden [&[disabled]>span.label-enabled]:hidden [&[disabled]>span.label-disabled]:block"
      >
        <span class="label-enabled pointer-events-none">
          Verify
        </span>

        <span class="label-disabled">
          <.spinner class="inline-block h-5 w-5 mr-2 text-white dark:text-gray-400" /> Verifying...
        </span>
      </.button>
    </div>
    """
  end
end
