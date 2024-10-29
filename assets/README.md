# Plausible frontend

## Testing

### 1. Jest component tests

React component tests can be run via `npm run test` or `npx jest`. These tests test individual react components using
[@testing-library/react](https://testing-library.com/)

### 2. Playwright tests

Playwright tests test the application end-to-end. Used to test interaction-heavy parts of Plausible like the dashboard.

Locally, the best way to run these tests is to:
1. Reset the database and re-seed: `mix ecto.reset`
2. Run tests in UI mode: `npm run --prefix assets playwright:ui`
