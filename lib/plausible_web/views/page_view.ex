defmodule PlausibleWeb.PageView do
  use PlausibleWeb, :view

  def base_domain do
    PlausibleWeb.Endpoint.host()
  end

  def plausible_url do
    PlausibleWeb.Endpoint.url()
  end
end
