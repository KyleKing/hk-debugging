# Playwright Troubleshooting Guide

Common issues and their solutions when working with Playwright tests.

## Locator Issues

### Element Not Found

**Problem:**
```
Error: locator.click: Target closed
Error: locator.click: Timeout 30000ms exceeded
```

**Solutions:**

1. **Wait for element to appear:**
```typescript
// ❌ Bad
await page.getByRole('button').click();

// ✅ Good
await page.getByRole('button').waitFor({ state: 'visible' });
await page.getByRole('button').click();
```

2. **Check if element is in iframe:**
```typescript
const frame = page.frameLocator('iframe[title="Content"]');
await frame.getByRole('button').click();
```

3. **Verify selector is correct:**
```typescript
// Debug: see what's actually on the page
console.log(await page.content());
await page.screenshot({ path: 'debug.png' });
```

### Selector Matches Multiple Elements

**Problem:**
```
Error: strict mode violation: locator('button') resolved to 5 elements
```

**Solutions:**

1. **Be more specific:**
```typescript
// ❌ Bad - too generic
await page.getByRole('button').click();

// ✅ Good - specific with name
await page.getByRole('button', { name: 'Submit' }).click();

// ✅ Good - combine selectors
await page.getByTestId('login-form').getByRole('button').click();
```

2. **Use first/last/nth:**
```typescript
// Click first match
await page.getByRole('button').first().click();

// Click specific index
await page.getByRole('button').nth(2).click();
```

### Element Detached from DOM

**Problem:**
```
Error: Element is not attached to the DOM
```

**Solutions:**

```typescript
// Wait for element to be stable
await page.getByRole('button').waitFor({ state: 'attached' });

// Or use locator that auto-retries
const button = page.getByRole('button');
await button.click(); // Auto-retries until element is stable
```

## Timing Issues

### Race Conditions

**Problem:**
Test passes locally but fails in CI.

**Solutions:**

1. **Never use fixed waits:**
```typescript
// ❌ Bad
await page.waitForTimeout(3000);

// ✅ Good - wait for specific state
await page.waitForLoadState('networkidle');
await page.getByText('Data loaded').waitFor();
```

2. **Wait for navigation:**
```typescript
// ❌ Bad
await page.getByRole('link').click();
await page.getByRole('heading'); // Might run before navigation

// ✅ Good
await page.getByRole('link').click();
await page.waitForURL('**/new-page');
```

3. **Wait for API calls:**
```typescript
const responsePromise = page.waitForResponse('**/api/data');
await page.getByRole('button', { name: 'Load' }).click();
const response = await responsePromise;
```

### Flaky Tests

**Problem:**
Tests fail intermittently.

**Solutions:**

1. **Increase timeout for slow operations:**
```typescript
test('slow operation', async ({ page }) => {
  test.setTimeout(60000); // 60 seconds

  await page.goto('/slow-page', { timeout: 30000 });
});
```

2. **Wait for network idle:**
```typescript
await page.goto('/', { waitUntil: 'networkidle' });
```

3. **Disable animations:**
```typescript
// In playwright.config.ts
use: {
  // Disable CSS animations
  hasTouch: false,
  // Can also use in specific test
}

// In test
await page.emulateMedia({ reducedMotion: 'reduce' });
```

## Authentication Issues

### Session Lost Between Tests

**Problem:**
Login works in first test, but subsequent tests are logged out.

**Solutions:**

1. **Use storage state:**
```typescript
// Save auth state once
test('setup', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill('password');
  await page.getByRole('button', { name: 'Sign in' }).click();

  await page.context().storageState({ path: 'auth.json' });
});

// Reuse in config
{
  name: 'authenticated',
  use: { storageState: 'auth.json' },
}
```

2. **Use fixtures:**
```typescript
export const test = base.extend({
  authenticatedPage: async ({ page }, use) => {
    // Login logic
    await use(page);
  },
});
```

### Cookie Issues

**Problem:**
Authentication cookies not persisting.

**Solutions:**

```typescript
// Set cookies manually
await context.addCookies([
  {
    name: 'session',
    value: 'token-value',
    domain: 'example.com',
    path: '/',
  },
]);

// Or load from saved state
const context = await browser.newContext({
  storageState: 'auth.json',
});
```

## Network Issues

### API Calls Failing

**Problem:**
Tests can't reach backend API.

**Solutions:**

1. **Check base URL:**
```typescript
// playwright.config.ts
use: {
  baseURL: process.env.BASE_URL || 'http://localhost:3000',
}
```

2. **Wait for dev server:**
```typescript
// playwright.config.ts
webServer: {
  command: 'npm run dev',
  url: 'http://localhost:3000',
  timeout: 120000,
  reuseExistingServer: !process.env.CI,
}
```

3. **Debug network:**
```typescript
page.on('request', req => console.log('>>', req.method(), req.url()));
page.on('response', res => console.log('<<', res.status(), res.url()));
```

### CORS Errors

**Problem:**
Cross-origin requests blocked.

**Solutions:**

```typescript
// Mock the API instead of calling real backend
await page.route('**/api/**', async route => {
  await route.fulfill({
    status: 200,
    body: JSON.stringify({ data: 'mock' }),
  });
});
```

## Browser-Specific Issues

### Tests Pass in Chromium, Fail in Firefox

**Problem:**
Browser compatibility issues.

**Solutions:**

1. **Skip on specific browser:**
```typescript
test('feature test', async ({ page, browserName }) => {
  test.skip(browserName === 'firefox', 'Not supported on Firefox yet');
  // Test code
});
```

2. **Different selectors for different browsers:**
```typescript
const isSafari = browserName === 'webkit';
const button = isSafari
  ? page.locator('button.submit')
  : page.getByRole('button', { name: 'Submit' });
```

### Headless vs Headed Differences

**Problem:**
Tests pass in headed mode, fail in headless.

**Solutions:**

```typescript
// Force headless in test
test.use({ headless: true });

// Or run with headed to debug
// npx playwright test --headed

// Slow down for visibility
test.use({ launchOptions: { slowMo: 50 } });
```

## Screenshot/Visual Issues

### Screenshot Comparison Failing

**Problem:**
Visual regression tests fail with minor differences.

**Solutions:**

1. **Adjust threshold:**
```typescript
await expect(page).toHaveScreenshot('home.png', {
  maxDiffPixels: 100,
  threshold: 0.2, // 20% difference allowed
});
```

2. **Mask dynamic content:**
```typescript
await expect(page).toHaveScreenshot({
  mask: [
    page.getByText(/Updated at:/),
    page.getByTestId('timestamp'),
  ],
});
```

3. **Disable animations:**
```typescript
await expect(page).toHaveScreenshot({
  animations: 'disabled',
});
```

4. **Update baseline:**
```bash
npx playwright test --update-snapshots
```

## Fixture Issues

### Fixture Not Working

**Problem:**
Custom fixture doesn't run or throws errors.

**Solutions:**

1. **Check fixture scope:**
```typescript
// Test-scoped (default)
const test = base.extend({
  myFixture: async ({}, use) => {
    await use('value');
  },
});

// Worker-scoped
const test = base.extend({
  workerFixture: [async ({}, use) => {
    await use('value');
  }, { scope: 'worker' }],
});
```

2. **Check auto option:**
```typescript
// Fixture runs automatically
const test = base.extend({
  autoFixture: [async ({}, use) => {
    await use();
  }, { auto: true }],
});
```

## Performance Issues

### Tests Running Slowly

**Solutions:**

1. **Run in parallel:**
```typescript
// playwright.config.ts
fullyParallel: true,
workers: process.env.CI ? 2 : undefined,
```

2. **Optimize page loads:**
```typescript
// Don't wait for everything
await page.goto('/', { waitUntil: 'domcontentloaded' });

// Block unnecessary resources
await page.route('**/*.{png,jpg,jpeg}', route => route.abort());
```

3. **Use storage state for auth:**
Don't log in on every test - save and reuse auth state.

### Too Much Memory Usage

**Solutions:**

```typescript
// Close contexts/pages explicitly
await page.close();
await context.close();

// Limit parallel workers
workers: 2,

// Use sharding
// npx playwright test --shard=1/4
```

## CI/CD Issues

### Tests Pass Locally, Fail in CI

**Solutions:**

1. **Match environment:**
```typescript
// playwright.config.ts
use: {
  baseURL: process.env.CI
    ? 'http://localhost:3000'
    : 'http://localhost:3000',
}
```

2. **Install dependencies:**
```bash
# In CI
npx playwright install --with-deps
```

3. **Check for CI-specific config:**
```typescript
retries: process.env.CI ? 2 : 0,
workers: process.env.CI ? 2 : undefined,
```

4. **Increase timeouts:**
```typescript
timeout: process.env.CI ? 60000 : 30000,
```

### Artifacts Not Saved

**Solutions:**

```yaml
# GitHub Actions
- uses: actions/upload-artifact@v3
  if: always()
  with:
    name: playwright-report
    path: playwright-report/
    retention-days: 30
```

## TypeScript Issues

### Type Errors

**Problem:**
TypeScript compilation errors in test files.

**Solutions:**

1. **Install types:**
```bash
npm install -D @playwright/test
npm install -D @types/node
```

2. **Update tsconfig.json:**
```json
{
  "compilerOptions": {
    "types": ["@playwright/test", "node"]
  }
}
```

3. **Import correctly:**
```typescript
import { test, expect, Page } from '@playwright/test';
```

## Debugging Techniques

### General Debugging

```typescript
// Pause execution
await page.pause();

// Take screenshot
await page.screenshot({ path: 'debug.png', fullPage: true });

// Print HTML
console.log(await page.content());

// Get text content
console.log(await page.getByRole('button').textContent());

// Check if element exists
console.log(await page.getByRole('button').count());
```

### Debug Specific Selector

```typescript
// Highlight element
await page.getByRole('button').highlight();

// Get bounding box
const box = await page.getByRole('button').boundingBox();
console.log(box);

// Check visibility
const isVisible = await page.getByRole('button').isVisible();
console.log('Is visible:', isVisible);
```

### Network Debugging

```typescript
// Log all requests
page.on('request', request => {
  console.log('>>', request.method(), request.url());
});

// Log failed requests
page.on('requestfailed', request => {
  console.log('FAILED:', request.url(), request.failure());
});

// Log responses
page.on('response', response => {
  console.log('<<', response.status(), response.url());
});
```

### Console Debugging

```typescript
// Capture browser console
page.on('console', msg => {
  console.log('Browser log:', msg.text());
});

// Capture errors
page.on('pageerror', error => {
  console.log('Page error:', error.message);
});
```

## Common Error Messages

### "Target closed"

**Cause:** Page or context closed before operation completed.

**Fix:**
```typescript
// Don't close page too early
await page.getByRole('button').click();
await page.waitForLoadState();
// Now it's safe to close
```

### "Execution context was destroyed"

**Cause:** Page navigated during operation.

**Fix:**
```typescript
// Wait for navigation to complete
await page.waitForLoadState('domcontentloaded');
```

### "Protocol error: Target closed"

**Cause:** Browser crashed or was killed.

**Fix:**
```typescript
// Increase browser timeout
launchOptions: {
  timeout: 60000,
}
```

### "Cannot find module"

**Cause:** Import path incorrect or module not installed.

**Fix:**
```bash
npm install
```

```typescript
// Check import paths
import { test } from '@playwright/test'; // Correct
```

## Best Practices to Avoid Issues

1. **Always use auto-waiting locators** instead of manual waits
2. **Use semantic selectors** (getByRole) for stability
3. **Implement proper error handling** with try-catch
4. **Keep tests isolated** - no shared state
5. **Use storage state** for authentication
6. **Configure retries** for flaky tests in CI
7. **Enable trace on failure** for debugging
8. **Mock external dependencies** to avoid flakiness
9. **Test in parallel** for speed
10. **Keep tests focused** - one behavior per test

## Getting Help

When stuck:

1. Enable debug mode: `npx playwright test --debug`
2. Check trace viewer: `npx playwright show-trace trace.zip`
3. Add verbose logging in test
4. Take screenshots at each step
5. Simplify test to isolate issue
6. Check Playwright GitHub issues
7. Review official documentation

## Resources

- [Official Troubleshooting Guide](https://playwright.dev/docs/debug)
- [GitHub Issues](https://github.com/microsoft/playwright/issues)
- [Discord Community](https://aka.ms/playwright/discord)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/playwright)
