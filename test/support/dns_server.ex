defmodule Plasusible.Test.Support.DNSServer do
  @moduledoc """
  A simple DNS server that responds to TXT queries with fixed sample values.
  """

  def start(fixed_response) do
    {:ok, socket} = :gen_udp.open(0, [:binary, active: true, ip: {0, 0, 0, 0}])
    {:ok, port} = :inet.port(socket)
    child = spawn(fn -> loop(socket, fixed_response) end)
    :ok = :gen_udp.controlling_process(socket, child)
    {:ok, port}
  end

  defp loop(socket, fixed_response) do
    receive do
      {:udp, _socket, client_ip, client_port, query} ->
        response = build_response(query, fixed_response)
        :gen_udp.send(socket, client_ip, client_port, response)
        loop(socket, fixed_response)
    end
  end

  defp build_response(query, response) do
    <<transaction_id::16, _flags::16, qdcount::16, _rest::binary>> = query

    header = <<
      # Transaction ID
      transaction_id::16,
      # Flags: Standard query response, no error
      0b10000100_00000000::16,
      # Questions: Echo the number of questions
      qdcount::16,
      # Answer RRs: 1
      1::16,
      # Authority RRs: 0
      0::16,
      # Additional RRs: 0
      0::16
    >>

    <<_header::binary-size(12), question::binary>> = query
    txt_data = encode_txt_data(response)

    answer = <<
      # Name: Pointer to the question
      0xC00C::16,
      # Type: TXT
      16::16,
      # Class: IN (Internet)
      1::16,
      # TTL: 60 seconds
      60::32,
      byte_size(txt_data)::16,
      txt_data::binary
    >>

    [header, question, answer]
  end

  defp encode_txt_data(txt_value) do
    <<byte_size(txt_value)::8, txt_value::binary>>
  end
end
