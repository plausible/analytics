defmodule Plausible.InstallationSupport.BrowserlessConfigTest do
  use ExUnit.Case
  use Plausible

  on_ee do
    doctest Plausible.InstallationSupport.BrowserlessConfig, import: true
  end
end
