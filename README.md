# PSF Plausible Analytics

This is the Python Software Foundation's fork of [Plausible Analytics](https://plausible.io/), 
running at [analytics.python.org](https://analytics.python.org). 
It tracks traffic across PSF infrastructure sites with privacy-friendly, cookie-free analytics.

The fork adds:
- A custom landing page at `/` with links to public dashboards
- Unix domain socket support for Cabotage deployments
- PSF-specific Procfile and Dockerfile configuration
- ClickHouse migration and replication settings for the PSF database topology
- Google API and GA4 import adjustments

The deployment branch for this baseline is `v3.2.1-psf`, incorporating upstream
[v3.2.1](https://github.com/plausible/analytics/releases/tag/v3.2.1).
The name identifies the latest incorporated CE release, not an unmodified release
tree: this fork also retains the previously imported upstream `master` snapshot
`dc51b4cc9c7107d9bed63fbe594c7c81fe702238` and subsequent PSF changes.

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

To edit the landing page, change `landing/index.html` and open a PR against the
deployment branch. Merge only after CI passes; Cabotage builds from its configured
branch.

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

Cabotage builds from its configured deployment branch. The transition from
`v3.0.1-psf` to `v3.2.1-psf` requires an explicit operator cutover; merging code or
editing this README does not change Cabotage's branch setting.

After the reconciliation PR passes CI and is merged **with a merge commit**:

1. Pause automatic deployment while changing branch references.
2. Rename the deployment branch from `v3.0.1-psf` to `v3.2.1-psf`, keeping its
   reviewed history. Update GitHub's default branch and applicable branch rules.
3. Change Cabotage's tracked branch to `v3.2.1-psf`, then resume automatic deployment.
4. Build and deploy through Cabotage. Verify the deployed source commit and image
   digest, migration completion, and application health.

Before this cutover, production continues to track the existing branch.

### Storybook security update

This fork backports the upstream removal of Storybook for [GHSA-mhcv-h7gf-57cf](https://github.com/plausible/analytics/security/advisories/GHSA-mhcv-h7gf-57cf). Deploy a newly built image containing the fix; the branch name alone does not identify patched code.

Until the patched image is deployed, block `/storybook` and its subpaths at every ingress, including direct-origin access. Preserve access logs and incident evidence. After deployment, verify the running commit and image digest and confirm that Storybook is unavailable.

If credentials were disclosed or compromise is suspected, rotate or revoke all secrets accessible to the container after containment and assess downstream access with PSRT. Use the supported rotation procedure for encryption keys. Deploying this patch does not invalidate stolen credentials.

## Upstream Sync

Track published upstream CE release tags, not the moving `master` branch.
For each release, create a review branch from the current PSF deployment branch
and merge the selected upstream tag into it. Keep the PSF and previously imported
upstream changes unless a reviewed migration deliberately replaces them.

The reconciliation to v3.2.1 restores the ancestry lost when PR #2 was
squash-merged: original merge `ec3f81de488b7aa9a6dcffc03cb9b33bcb53cda1`
has the same tree as squash commit `2d3391215fd26fe3a4a2e54c083e4ffb5ebe7b60`.
The ancestry repair preserves the current PSF tree, then incorporates the
upstream v3.2.1 tag.

**Use merge commits for upstream synchronization PRs, including this ancestry
repair. Do not squash or rebase them.** A repository administrator must enable
merge commits before merging if the repository only permits squash merges.

Review the landing page and controller, Unix socket configuration, Dockerfile and
Procfile, ClickHouse migrations and replication paths, Google API/GA4 import
adjustments, Storybook removal, and MinIO test setup during every synchronization.
Preserve applied migration history; do not reset the fork to a stock release tree.

Require CI and a production-image build before merging. If migrations change,
validate them against a restored database copy before production deployment.
After review, rename the deployment branch to `v<upstream-version>-psf` and update
GitHub, Cabotage, and these instructions together. Record the upstream tag, PSF
commit, and deployed image digest for each deployment.

## License

Plausible CE is open source under the [GNU Affero General Public License Version 3](LICENSE.md). The JavaScript tracker is [MIT licensed](tracker/LICENSE.md).

Copyright (c) 2018-present Plausible Insights OÜ.
