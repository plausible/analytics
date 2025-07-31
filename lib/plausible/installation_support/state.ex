defmodule Plausible.InstallationSupport.State do
  @moduledoc """
  The state to be shared across check during site installation support.

  Assigns are meant to be used to communicate between checks, while
  `diagnostics` are specific to the check group being executed.
  """

  defstruct url: nil,
            data_domain: nil,
            report_to: nil,
            assigns: %{},
            diagnostics: %{}

  @type diagnostics_type ::
          Plausible.InstallationSupport.LegacyVerification.Diagnostics.t()
          | Plausible.InstallationSupport.Verification.Diagnostics.t()

  @type t :: %__MODULE__{
          url: String.t() | nil,
          data_domain: String.t() | nil,
          report_to: pid() | nil,
          assigns: map(),
          diagnostics: diagnostics_type()
        }

  def assign(%__MODULE__{} = state, assigns) do
    %{state | assigns: Map.merge(state.assigns, Enum.into(assigns, %{}))}
  end

  def put_diagnostics(%__MODULE__{} = state, diagnostics) when is_list(diagnostics) do
    %{state | diagnostics: struct!(state.diagnostics, diagnostics)}
  end

  def put_diagnostics(%__MODULE__{} = state, diagnostics) do
    put_diagnostics(state, List.wrap(diagnostics))
  end
end
