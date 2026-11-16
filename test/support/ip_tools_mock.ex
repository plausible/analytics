# Compiled rather than defined in test_helper.exs, because `Plausible.SSRF`
# picks it at compile time. Dev compiles test/support too, but Mox is test-only.
if Code.ensure_loaded?(Mox) do
  Mox.defmock(Plausible.IP.Tools.Mock, for: Plausible.IP.ToolsInterface)
end
