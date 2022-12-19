# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v1.6.3](https://github.com/checkly/terraform-provider-checkly/releases/tag/v1.6.3) - 2022-10-26

### Added
- Support locked environment variables in `Check` and `Group`[#186](https://github.com/checkly/terraform-provider-checkly/issues/186)
- Add new `Dashboard` fields [#199](https://github.com/checkly/terraform-provider-checkly/issues/199)

### Changed
- Remove guides from provider documentation [#196](https://github.com/checkly/terraform-provider-checkly/issues/196)
- Add alternatives auth methods in documentation [#191](https://github.com/checkly/terraform-provider-checkly/issues/191)
- Follow resource naming convention in examples [#190](https://github.com/checkly/terraform-provider-checkly/issues/190)


### Fixed
- Avoid using all escalation configuration when no required [#202](https://github.com/checkly/terraform-provider-checkly/issues/194)
- Stop saving deprecated `ssl_certificates` property [#193](https://github.com/checkly/terraform-provider-checkly/issues/193)



## [v1.6.2](https://github.com/checkly/terraform-provider-checkly/releases/tag/v1.6.2) - 2022-08-02
### Changed
- Support new check intervals [#ba8eed7](https://github.com/checkly/terraform-provider-checkly/commit/ba8eed7)
### Fixed
- Fix style issues [#dc55746](https://github.com/checkly/terraform-provider-checkly/commit/dc55746)

## [v1.6.1](https://github.com/checkly/terraform-provider-checkly/releases/tag/v1.6.1) - 2022-07-06
### Changed
- Make `locations` property from `Group` optional [#2901337](https://github.com/checkly/terraform-provider-checkly/commit/2901337)
### Fixed
- Fix `PrivateLocation` docs which were missing [#d99105f](https://github.com/checkly/terraform-provider-checkly/commit/d99105f)

## [v1.6.0](https://github.com/checkly/terraform-provider-checkly/releases/tag/v1.6.0) - 2022-06-21
### Added
- Support Private Locations resources [#164](https://github.com/checkly/terraform-provider-checkly/issues/164)
- Allow Checks/Groups use private locations [#159](https://github.com/checkly/terraform-provider-checkly/issues/159)

## [v1.5.0](https://github.com/checkly/terraform-provider-checkly/releases/tag/v1.5.0) - 2022-06-21

### Added
- Support for global Environment Variables [#41](https://github.com/checkly/terraform-provider-checkly/issues/41)
- Implemented tfdocs for automatic docs generation [#125](https://github.com/checkly/terraform-provider-checkly/issues/125)

### Changed
- Remove unneeded `required` from `PublicDashboard`[#121](https://github.com/checkly/terraform-provider-checkly/issues/121)
- Remove unneeded `required` from `MaintenanceWindow`[#140](https://github.com/checkly/terraform-provider-checkly/issues/140)
- Improve CI and local tooling [#130](https://github.com/checkly/terraform-provider-checkly/issues/130)
- Update TF SDK and refactor local build [#124](https://github.com/checkly/terraform-provider-checkly/pull/124)
- Flag `sslCertificates` as deprecated [#137](https://github.com/checkly/terraform-provider-checkly/pull/137)
- Migrate to new Terraform schema Importer [#138](https://github.com/checkly/terraform-provider-checkly/pull/138)
- Allow set empty `locations` in checks within groups [#98](https://github.com/checkly/terraform-provider-checkly/issues/98)
- Bump github.com/google/go-cmp to v0.5.8 [#149](https://github.com/checkly/terraform-provider-checkly/pull/149)
- Bump github/codeql-action to v2 [#148](https://github.com/checkly/terraform-provider-checkly/pull/148)
- Bump hashicorp/setup-terraform to v2 [#146](https://github.com/checkly/terraform-provider-checkly/pull/146)
- Bump goreleaser/goreleaser-action to v3 [#154](https://github.com/checkly/terraform-provider-checkly/pull/154)
- Bump actions/setup-go to v3 [#154](https://github.com/checkly/terraform-provider-checkly/pull/154)
- Bump github.com/gruntwork-io/terratest to v0.40.17 [#169](https://github.com/checkly/terraform-provider-checkly/pull/169)
- Bump actions/checkout to v3 [#132](https://github.com/checkly/terraform-provider-checkly/pull/132)
- Bump github.com/checkly/checkly-go-sdk to v1.5.7 [#134](https://github.com/checkly/terraform-provider-checkly/pull/134)
- Bump github.com/hashicorp/terraform-plugin-sdk/v2 to v2.12.0 [#135](https://github.com/checkly/terraform-provider-checkly/pull/135)

## [v1.4.3](https://github.com/checkly/terraform-provider-checkly/releases/tag/v1.4.3) - 2022-03-09
### Changed
- Use generic provider descriptions in docs [#e7bb925](https://github.com/checkly/terraform-provider-checkly/commit/e7bb925)

## [v1.4.2](https://github.com/checkly/terraform-provider-checkly/releases/tag/v1.4.2) - 2022-03-02
### Added
- Add `CHECKLY_API_SOURCE` env variable [#120](https://github.com/checkly/terraform-provider-checkly/issues/120)

## [v1.4.1](https://github.com/checkly/terraform-provider-checkly/releases/tag/v1.4.1) - 2022-02-08

### Changed
- Migrate project test cases to User API Keys [#b35d8a7](https://github.com/checkly/terraform-provider-checkly/commit/b35d8a7)

## [v1.4.0](https://github.com/checkly/terraform-provider-checkly/releases/tag/v1.4.0) - 2022-01-28
### Added
- Support for Command Line Triggers [#87](https://github.com/checkly/terraform-provider-checkly/issues/87)
- Add Public API `source` HTTP header [#110](https://github.com/checkly/terraform-provider-checkly/issues/110)
- Allow skip ssl validation to api checks [#112](https://github.com/checkly/terraform-provider-checkly/issues/112)

### Changed
- Made check/group `locations` property optional [#103](https://github.com/checkly/terraform-provider-checkly/issues/103)
- Rename default branch to `main` [#99](https://github.com/checkly/terraform-provider-checkly/issues/99)
- Improve User API Keys docs [#95](https://github.com/checkly/terraform-provider-checkly/issues/95)

## [v1.3.0](https://github.com/checkly/terraform-provider-checkly/releases/tag/v1.3.0) - 2021-11-10
### Added
- Support for Public Dashboards [#81](https://github.com/checkly/terraform-provider-checkly/issues/81)
- Support for Maintenance Windows [#83](https://github.com/checkly/terraform-provider-checkly/issues/83)
- Support for User API Keys [#88](https://github.com/checkly/terraform-provider-checkly/issues/88)

## [v1.2.1](https://github.com/checkly/terraform-provider-checkly/releases/tag/v1.2.1) - 2021-10-19
### Changed
- Fix optional and required values in webhooks alert channels [#82](https://github.com/checkly/terraform-provider-checkly/pull/82)

## [v1.2.0](https://github.com/checkly/terraform-provider-checkly/releases/tag/v1.2.0) - 2021-07-14
### Added
- Support for versioned runtimes  [#31](https://github.com/checkly/checkly-go-sdk/issues/31).
- Support for PagerDuty alert channels integration [#53](https://github.com/checkly/terraform-provider-checkly/issues/53).


## [v1.1.0](https://github.com/checkly/terraform-provider-checkly/releases/tag/v1.1.0) - 2021-05-28
### Added
- Support for API high frequency checks [#68](https://github.com/checkly/terraform-provider-checkly/issues/68).
- Add `setupSnippetId` and `teardownSnippetID` to `check_group` resource [#69](https://github.com/checkly/terraform-provider-checkly/issues/69).

## [v1.0.0](https://github.com/checkly/terraform-provider-checkly/releases/tag/v1.4.3) - 2021-04-09
### Added
- Apple Silicon support is now added. The Terraform provider now also has `darwin_arm64` binaries

### Changed
- [🚨 BREAKING CHANGE] The default behavior of assigning all alert channels to checks and check groups is now removed. You can add alerts to your checks and check groups using the `alert_channel_subscription`
- Support for go1.16
