defmodule Mix.Tasks.ObtainSslCertificatesTest do
  use Plausible.DataCase
  alias Mix.Tasks.ObtainSslCertificates
  import Double

  test "makes ssh call to certbot" do
    site = insert(:site)
    insert(:custom_domain, site: site, domain: "custom-site.com")

    system_stub = stub(System, :cmd, fn(_cmd, _args) -> {"", 0} end)
    ObtainSslCertificates.execute(system_stub)

    assert_receive({System, :cmd, ["ssh", ["-t", "ubuntu@custom.plausible.io", "sudo certbot certonly --nginx -n -d custom-site.com"]]})
  end

  test "sets has_ssl_certficate=true if the ssh command is succesful" do
    site = insert(:site)
    insert(:custom_domain, site: site, domain: "custom-site.com")

    system_stub = stub(System, :cmd, fn(_cmd, _args) -> {"", 0} end)
    ObtainSslCertificates.execute(system_stub)

    domain = Repo.get_by(Plausible.Site.CustomDomain, site_id: site.id)
    assert domain.has_ssl_certificate
  end

  test "does not set has_ssl_certficate=true if the ssh command fails" do
    site = insert(:site)
    insert(:custom_domain, site: site, domain: "custom-site.com")

    failing_system_stub = stub(System, :cmd, fn(_cmd, _args) -> {"", 1} end)
    ObtainSslCertificates.execute(failing_system_stub)

    domain = Repo.get_by(Plausible.Site.CustomDomain, site_id: site.id)
    refute domain.has_ssl_certificate
  end
end
