defmodule PlausibleWeb.RefInspector do
  def parse(nil), do: nil

  def parse(ref) do
    case ref.source do
      :unknown ->
        uri = URI.parse(String.trim(ref.referer))

        if right_uri?(uri) do
          String.replace_leading(uri.host, "www.", "")
        end

      source ->
        source
    end
  end

  def right_uri?(%URI{host: nil}), do: false

  def right_uri?(%URI{host: host, scheme: scheme})
      when scheme in ["http", "https"] and byte_size(host) > 0,
      do: true

  def right_uri?(_), do: false
end
