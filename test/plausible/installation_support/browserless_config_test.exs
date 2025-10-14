defmodule Plausible.InstallationSupport.BrowserlessConfigTest do
  use Plausible
  use ExUnit.Case

  on_ee do
    doctest Plausible.InstallationSupport.BrowserlessConfig, import: true
  end
end
