defmodule Plausible.Workers.SslCertificatesTest do
  use Plausible.DataCase
  alias Plausible.Workers.ProvisionSslCertificates
  import Double

  test "makes ssh call to certbot" do
    site = insert(:site)
    insert(:custom_domain, site: site, domain: "custom-site.com")

    ssh_stub =
      stub(SSHEx, :connect, fn _cmd -> {:ok, nil} end)
      |> stub(:run, fn _conn, _cmd, _opts -> {:ok, "", 0} end)

    ProvisionSslCertificates.perform(nil, ssh_stub)

    assert_receive(
      {SSHEx, :run,
       [nil, 'sudo certbot certonly --webroot -w /root/webroot -n -d "custom-site.com"', _]}
    )
  end

  test "sets has_ssl_certficate=true if the ssh command is succesful" do
    site = insert(:site)
    insert(:custom_domain, site: site, domain: "custom-site.com")

    ssh_stub =
      stub(SSHEx, :connect, fn _cmd -> {:ok, nil} end)
      |> stub(:run, fn _conn, _cmd, _opts -> {:ok, "", 0} end)

    ProvisionSslCertificates.perform(nil, ssh_stub)

    domain = Repo.get_by(Plausible.Site.CustomDomain, site_id: site.id)
    assert domain.has_ssl_certificate
  end

  test "does not set has_ssl_certficate=true if the ssh command fails" do
    site = insert(:site)
    insert(:custom_domain, site: site, domain: "custom-site.com")

    ssh_stub =
      stub(SSHEx, :connect, fn _cmd -> {:ok, nil} end)
      |> stub(:run, fn _conn, _cmd, _opts -> {:ok, "", 1} end)

    ProvisionSslCertificates.perform(nil, ssh_stub)

    domain = Repo.get_by(Plausible.Site.CustomDomain, site_id: site.id)
    refute domain.has_ssl_certificate
  end

  test "does not set has_ssl_certficate=true if the ssh command errors completely" do
    site = insert(:site)
    insert(:custom_domain, site: site, domain: "custom-site.com")

    ssh_stub =
      stub(SSHEx, :connect, fn _cmd -> {:ok, nil} end)
      |> stub(:run, fn _conn, _cmd, _opts -> {:error, "msg"} end)

    ProvisionSslCertificates.perform(nil, ssh_stub)

    domain = Repo.get_by(Plausible.Site.CustomDomain, site_id: site.id)
    refute domain.has_ssl_certificate
  end
end
