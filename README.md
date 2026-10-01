# PSF Plausible Analytics

This is the Python Software Foundation's fork of [Plausible Analytics](https://plausible.io/), 
running at [analytics.python.org](https://analytics.python.org). 
It tracks traffic across PSF infrastructure sites with privacy-friendly, cookie-free analytics.

The fork adds a few things on top of upstream Plausible CE:
- A custom landing page at `/` with links to public dashboards
- Unix domain socket support for Cabotage deployments
- PSF-specific Procfile and Dockerfile configuration

We try to sync with [upstream](https://github.com/plausible/analytics) periodically. 
PSF-specific changes live on the `v3.0.1-psf` branch.

## Examples of Public Dashboards

These are open to everyone, no login required:

- [python.org](https://analytics.python.org/python.org)
- [docs.python.org](https://analytics.python.org/docs.python.org)
- [devguide.python.org](https://analytics.python.org/devguide.python.org)
- [peps.python.org](https://analytics.python.org/peps.python.org)
- [packaging.python.org](https://analytics.python.org/packaging.python.org)

## Requesting a New Site

To add a new PSF property to analytics.python.org, open an issue on this repo or reach out to the Infrastructure team. Include:

- The domain (e.g. `us.pycon.org`)
- Whether the dashboard should be public or private
- Who needs admin access

The infra team will create the site, provide the tracking snippet, and configure visibility.

## Making a Site's Dashboard Public

By default, dashboards are private (team-only). 
To make one publicly visible, ask the infra team to toggle the "Public" setting for that site. 
Once public, anyone can view the dashboard at `analytics.python.org/<domain>` without logging in.

## Landing Page

The landing page at `/` is a static HTML file at `landing/index.html`. 
It gets baked into the Docker image and served by the Phoenix app through `PageController`. 
Logged-in users get redirected to `/sites` as usual.

To edit the landing page, change `landing/index.html` and push to `v3.0.1-psf`. 
The next image build and deploy picks it up.

## Local Development

### Prerequisites

Docker. It uses:

- Elixir 1.19+, Erlang/OTP 27+
- PostgreSQL 16+
- ClickHouse 24.3+
- Node.js 23+

### Setup

```bash
mix deps.get
mix ecto.create
mix ecto.migrate
mix download_country_database
npm install --prefix assets
npm install --prefix tracker
npm run deploy --prefix tracker
```

### Run the dev server

```bash
make server
```

The app starts at `http://localhost:8000`.

### Preview the landing page

If you only need to iterate on the landing page HTML without running the full Elixir stack:

```bash
cd landing && python3 -m http.server 3000
```

Open `http://localhost:3000`. The links won't resolve (no Plausible backend), but you can check layout and styling.

### Makefile shortcuts

```
make help             Show available targets
make server           Start the dev server (mix phx.server)
make install          Full setup (deps, DB, assets)
make clickhouse       Start ClickHouse in Docker
make postgres         Start PostgreSQL in Docker
```

## Deployment

This runs on [Cabotage](https://github.com/cabotage/cabotage-app), the PSF's PaaS. The Procfile defines two processes:

- `web` — the Plausible Phoenix app, binds to a unix socket via `HTTPS_UDS`
- `release` — runs database migrations on deploy

Image builds happen automatically from the `v3.0.1-psf` branch. To deploy, trigger a build and deploy through the Cabotage UI.

### Storybook security update

This fork backports the upstream removal of Storybook for [GHSA-mhcv-h7gf-57cf](https://github.com/plausible/analytics/security/advisories/GHSA-mhcv-h7gf-57cf). Deploy a newly built image containing the fix; the branch name alone does not identify patched code.

Until the patched image is deployed, block `/storybook` and its subpaths at every ingress, including direct-origin access. Preserve access logs and incident evidence. After deployment, verify the running commit and image digest and confirm that Storybook is unavailable.

If credentials were disclosed or compromise is suspected, rotate or revoke all secrets accessible to the container after containment and assess downstream access with PSRT. Use the supported rotation procedure for encryption keys. Deploying this patch does not invalidate stolen credentials.

## Upstream Sync

This fork tracks `plausible/analytics:master` as the `upstream` remote.

```bash
git fetch upstream
git checkout v3.0.1-psf
git merge upstream/master
# resolve any conflicts in PSF-specific files
git push
```

PSF-specific changes are minimal (landing page, PageController, unix socket patch, Procfile/Dockerfile) so conflicts are rare.

## License

Plausible CE is open source under the [GNU Affero General Public License Version 3](LICENSE.md). The JavaScript tracker is [MIT licensed](tracker/LICENSE.md).

Copyright (c) 2018-present Plausible Insights OÜ.
