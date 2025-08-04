# Changelog

All notable changes to this npm library will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## [0.3.6] - 2025-08-04

- Fix issue with a second init() call changing the config option unexpectedly.

## [0.3.5] - 2025-08-04

- Fix issue with link tracking features (tagged events, file downloads, outbound links) causing errors on the page when clicking on `a` tags within `svg` tags.

## [0.3.4] - 2025-07-23

- Plausible loaded indicator `window.plausible.l = true` is set last in initialisation functions

## [0.3.3] - 2025-07-22

- Bind the `track` function into `window.plausible`. This makes it possible for the Plausible verification agent to verify a successful installation. Can be disabled setting the `bindToWindow` config option to `false`.

## [0.3.2] - 2025-07-14

- "Form: Submission" event payload does not need to contain props.path any more: it is saved to be the same as the pathname of the event

## [0.3.1] - 2025-07-08

- Do not send "Form: Submission" event if the form is tagged

## [0.3.0] - 2025-06-27

- Remove now unnecessary navigation delays on link clicks and form submissions.

## [0.2.4] - 2025-06-19

- Add `logging` option
- Improve `callback` option
- Improve `fileDownloads` typing, export `DEFAULT_FILE_TYPES`

## [0.2.2] - 2025-06-16

- Support for `config.transformRequest`
- Support for passing `url` as option when calling `track`
- Drop support for `meta` argument.
