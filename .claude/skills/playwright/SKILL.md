---
name: playwright
description: Expert guide for writing, debugging, and maintaining Playwright browser automation tests. Use when user needs to create tests, automate browser workflows, perform visual regression testing, or debug existing Playwright code. Covers test generation, Page Object Model, fixtures, assertions, locator strategies, and modern best practices.
allowed-tools: Read,Write,Edit,Bash,Grep,Glob
---

# Playwright Browser Automation & Testing Expert

You are an expert in Playwright browser automation and testing. Help users write robust, maintainable tests following 2025 best practices.

## Core Principles

1. **User-Centric Testing**: Write tests that mirror real user behavior
2. **Semantic Locators First**: Prioritize accessibility-based selectors
3. **Auto-Waiting**: Leverage Playwright's built-in waiting mechanisms
4. **Isolation**: Each test should be independent and isolated
5. **Maintainability**: Write clean, readable code that's easy to update

## When to Use This Skill

- Writing new Playwright tests
- Debugging failing tests
- Implementing Page Object Model
- Setting up fixtures and test configuration
- Adding visual regression testing
- Creating browser automation workflows
- Optimizing test performance and reliability

## Test Creation Workflow

### Step 1: Understand the Requirement

Ask clarifying questions if needed:
- What user flow should be tested?
- What assertions are critical?
- Desktop only or multiple viewports?
- Visual regression needed?
- Authentication required?

### Step 2: Choose Test Structure

**Simple Test** (for quick validation):
```typescript
import { test, expect } from '@playwright/test';

test('homepage loads correctly', async ({ page }) => {
  await page.goto('https://example.com');
  await expect(page).toHaveTitle(/Example/);
});
```

**Page Object Model** (for complex apps with many tests):
- Create page classes in `tests/pages/` or `pages/`
- Encapsulate selectors and actions
- Use when you have 5+ tests or repeated interactions

**Fixtures** (for custom test setup):
- Use for shared state (authenticated users, test data)
- Create reusable test contexts
- Implement in `playwright.config.ts` or separate fixture files

### Step 3: Implement Using Best Practices

Follow the guidelines below for locators, assertions, and error handling.

## Locator Strategy (Priority Order)

Always use locators in this priority order:

### 1. getByRole (Highest Priority)
Reflects how users and assistive technology perceive the page.

```typescript
// ✅ BEST: Role + accessible name
await page.getByRole('button', { name: 'Submit' }).click();
await page.getByRole('heading', { name: 'Welcome' }).isVisible();
await page.getByRole('textbox', { name: 'Email' }).fill('user@example.com');

// Common roles: button, link, textbox, heading, checkbox, radio, etc.
```

### 2. getByLabel (Forms)
Best for form inputs with labels.

```typescript
// ✅ GOOD: For labeled form fields
await page.getByLabel('Email address').fill('user@example.com');
await page.getByLabel('Password').fill('secret');
await page.getByLabel('Remember me').check();
```

### 3. getByPlaceholder (Input Hints)
Use when placeholder text is the primary identifier.

```typescript
// ✅ GOOD: When placeholder is clear and stable
await page.getByPlaceholder('Search...').fill('Playwright');
```

### 4. getByText (Visible Text)
Locate elements by their text content.

```typescript
// ✅ GOOD: For unique text content
await page.getByText('Welcome back!').isVisible();
await page.getByText('Sign up', { exact: true }).click();
```

### 5. getByTestId (Fallback)
Use when semantic locators aren't sufficient.

```typescript
// ✅ ACCEPTABLE: For complex or dynamic UIs
await page.getByTestId('submit-button').click();
await page.getByTestId('user-profile-menu').click();

// Configure custom test id attribute in playwright.config.ts:
// testIdAttribute: 'data-testid' // or 'data-test-id', 'data-cy', etc.
```

### 6. CSS/XPath (Last Resort)
Avoid unless absolutely necessary - brittle and hard to maintain.

```typescript
// ❌ AVOID: Fragile and not user-centric
await page.locator('.btn-primary.submit').click();
await page.locator('xpath=//div[@class="content"]//button').click();
```

## Assertions Best Practices

Use Playwright's auto-waiting assertions with appropriate timeouts.

### Common Assertions

```typescript
// Visibility
await expect(page.getByRole('heading')).toBeVisible();
await expect(page.getByText('Error')).toBeHidden();

// Content
await expect(page).toHaveTitle(/Dashboard/);
await expect(page).toHaveURL(/\/dashboard/);
await expect(page.getByRole('heading')).toHaveText('Welcome');
await expect(page.getByRole('heading')).toContainText('Welcome');

// State
await expect(page.getByRole('button')).toBeEnabled();
await expect(page.getByRole('button')).toBeDisabled();
await expect(page.getByRole('checkbox')).toBeChecked();

// Counts
await expect(page.getByRole('listitem')).toHaveCount(5);

// Attributes
await expect(page.getByRole('link')).toHaveAttribute('href', '/about');

// Screenshots (visual regression)
await expect(page).toHaveScreenshot('homepage.png');
await expect(page.getByTestId('card')).toHaveScreenshot('card.png');
```

### Soft Assertions

Use when you want to collect multiple failures in one test.

```typescript
test('multiple checks', async ({ page }) => {
  await page.goto('https://example.com');

  // These don't stop test execution on failure
  await expect.soft(page.getByRole('heading')).toBeVisible();
  await expect.soft(page.getByRole('button')).toBeEnabled();
  await expect.soft(page).toHaveTitle(/Example/);

  // Test continues and reports all failures
});
```

### Custom Timeouts

```typescript
// Override default 5s timeout for specific assertion
await expect(page.getByRole('button')).toBeVisible({ timeout: 10000 });

// Or configure globally in playwright.config.ts:
// expect: { timeout: 10000 }
```

## Error Handling & Debugging

### Use Auto-Waiting (Not Fixed Delays)

```typescript
// ❌ BAD: Fixed timeouts are brittle
await page.click('button');
await page.waitForTimeout(3000); // Don't do this!

// ✅ GOOD: Wait for specific conditions
await page.getByRole('button').click();
await page.waitForURL('**/dashboard');
await page.waitForLoadState('networkidle');
```

### Implement Proper Try-Catch

```typescript
test('with error handling', async ({ page }) => {
  try {
    await page.goto('https://example.com');
    await page.getByRole('button', { name: 'Submit' }).click();
    await expect(page).toHaveURL(/success/);
  } catch (error) {
    // Take screenshot on failure
    await page.screenshot({ path: 'error.png', fullPage: true });
    throw error; // Re-throw to fail the test
  }
});
```

### Use Test Steps for Better Debugging

```typescript
test('checkout flow', async ({ page }) => {
  await test.step('Login', async () => {
    await page.goto('https://example.com/login');
    await page.getByLabel('Email').fill('user@example.com');
    await page.getByLabel('Password').fill('password');
    await page.getByRole('button', { name: 'Sign in' }).click();
  });

  await test.step('Add to cart', async () => {
    await page.getByRole('button', { name: 'Add to Cart' }).click();
    await expect(page.getByText('Item added')).toBeVisible();
  });

  await test.step('Checkout', async () => {
    await page.getByRole('link', { name: 'Cart' }).click();
    await page.getByRole('button', { name: 'Checkout' }).click();
  });
});
```

## Page Object Model (POM)

Use POM for applications with multiple tests and repeated interactions.

### When to Use POM

- Large application with 5+ tests
- Repeated page interactions across tests
- Multiple team members maintaining tests
- Need to centralize selector management

### POM Structure

```typescript
// pages/LoginPage.ts
import { Page, Locator } from '@playwright/test';

export class LoginPage {
  readonly page: Page;
  readonly emailInput: Locator;
  readonly passwordInput: Locator;
  readonly submitButton: Locator;
  readonly errorMessage: Locator;

  constructor(page: Page) {
    this.page = page;
    // Use semantic locators
    this.emailInput = page.getByLabel('Email');
    this.passwordInput = page.getByLabel('Password');
    this.submitButton = page.getByRole('button', { name: 'Sign in' });
    this.errorMessage = page.getByRole('alert');
  }

  async goto() {
    await this.page.goto('/login');
  }

  async login(email: string, password: string) {
    await this.emailInput.fill(email);
    await this.passwordInput.fill(password);
    await this.submitButton.click();
  }

  async expectError(message: string) {
    await expect(this.errorMessage).toContainText(message);
  }
}
```

### Using Page Objects in Tests

```typescript
// tests/login.spec.ts
import { test, expect } from '@playwright/test';
import { LoginPage } from '../pages/LoginPage';

test('successful login', async ({ page }) => {
  const loginPage = new LoginPage(page);

  await loginPage.goto();
  await loginPage.login('user@example.com', 'validPassword');

  await expect(page).toHaveURL(/dashboard/);
});
```

### POM Best Practices

1. **Single Responsibility**: One page object per page/component
2. **User Actions as Methods**: Name methods after user actions (login, search, addToCart)
3. **Return Page Objects**: Methods that navigate should return new page objects
4. **No Assertions in Page Objects**: Keep assertions in tests (except helper validation methods)
5. **Composition Over Inheritance**: Use components for reusable UI elements (header, footer)

## Fixtures

Fixtures provide test setup and teardown with dependency injection.

### Built-in Fixtures

```typescript
test('using built-in fixtures', async ({ page, context, browser }) => {
  // page: isolated browser page
  // context: browser context (cookies, storage)
  // browser: browser instance
});
```

### Custom Fixtures

```typescript
// fixtures/auth.ts
import { test as base } from '@playwright/test';
import { LoginPage } from '../pages/LoginPage';

type AuthFixtures = {
  authenticatedPage: Page;
};

export const test = base.extend<AuthFixtures>({
  authenticatedPage: async ({ page }, use) => {
    // Setup: Login before each test
    const loginPage = new LoginPage(page);
    await loginPage.goto();
    await loginPage.login('user@example.com', 'password');

    // Provide authenticated page to test
    await use(page);

    // Teardown: happens automatically
  },
});

export { expect } from '@playwright/test';
```

### Using Custom Fixtures

```typescript
import { test, expect } from './fixtures/auth';

test('dashboard requires auth', async ({ authenticatedPage }) => {
  // Page is already logged in
  await authenticatedPage.goto('/dashboard');
  await expect(authenticatedPage).toHaveURL(/dashboard/);
});
```

### Advanced Fixture Patterns

```typescript
// fixtures/testData.ts
export const test = base.extend({
  // Worker-scoped (shared across tests in worker)
  testDataSetup: [async ({ browser }, use) => {
    // Setup expensive resources once per worker
    const data = await setupTestData();
    await use(data);
    await cleanupTestData(data);
  }, { scope: 'worker' }],

  // Test-scoped (isolated per test)
  uniqueUser: async ({ testDataSetup }, use) => {
    const user = await createUniqueUser();
    await use(user);
    await deleteUser(user);
  },
});
```

## Visual Regression Testing

### Screenshot Comparison

```typescript
test('homepage visual regression', async ({ page }) => {
  await page.goto('https://example.com');

  // Full page screenshot
  await expect(page).toHaveScreenshot('homepage.png');

  // Component screenshot
  await expect(page.getByTestId('header')).toHaveScreenshot('header.png');

  // With options
  await expect(page).toHaveScreenshot('homepage.png', {
    maxDiffPixels: 100, // Allow minor differences
    threshold: 0.2,     // 20% threshold
    fullPage: true,
  });
});
```

### Masking Dynamic Content

```typescript
test('masked visual regression', async ({ page }) => {
  await page.goto('https://example.com');

  await expect(page).toHaveScreenshot({
    mask: [
      page.getByText('Updated at:'),  // Mask timestamps
      page.getByTestId('user-avatar'), // Mask dynamic images
    ],
  });
});
```

### Multi-Viewport Testing

```typescript
const viewports = [
  { name: 'mobile', width: 375, height: 667 },
  { name: 'tablet', width: 768, height: 1024 },
  { name: 'desktop', width: 1920, height: 1080 },
];

viewports.forEach(({ name, width, height }) => {
  test(`homepage on ${name}`, async ({ page }) => {
    await page.setViewportSize({ width, height });
    await page.goto('https://example.com');
    await expect(page).toHaveScreenshot(`homepage-${name}.png`);
  });
});
```

### Updating Baselines

```bash
# Update all screenshots
npx playwright test --update-snapshots

# Update specific test
npx playwright test homepage.spec.ts --update-snapshots
```

## Configuration Best Practices

### playwright.config.ts Structure

```typescript
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  // Test directory
  testDir: './tests',

  // Run tests in parallel
  fullyParallel: true,

  // Fail build on CI if you accidentally left test.only
  forbidOnly: !!process.env.CI,

  // Retry on CI only
  retries: process.env.CI ? 2 : 0,

  // Reporters
  reporter: [
    ['html'],
    ['list'],
    ['junit', { outputFile: 'results.xml' }],
  ],

  // Shared settings for all tests
  use: {
    // Base URL for page.goto('/')
    baseURL: 'http://localhost:3000',

    // Collect trace on first retry
    trace: 'on-first-retry',

    // Screenshot on failure
    screenshot: 'only-on-failure',

    // Video on failure
    video: 'retain-on-failure',

    // Custom test id attribute
    testIdAttribute: 'data-testid',
  },

  // Configure projects for multiple browsers
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
    },
    {
      name: 'mobile-chrome',
      use: { ...devices['Pixel 5'] },
    },
  ],

  // Web server startup
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 120000,
  },
});
```

## Common Patterns & Solutions

### Handle Authentication

```typescript
// Save authenticated state
test('setup auth', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill('password');
  await page.getByRole('button', { name: 'Sign in' }).click();

  // Save storage state
  await page.context().storageState({ path: 'auth.json' });
});

// Reuse in playwright.config.ts
projects: [
  {
    name: 'setup',
    testMatch: /.*\.setup\.ts/,
  },
  {
    name: 'authenticated',
    use: { storageState: 'auth.json' },
    dependencies: ['setup'],
  },
]
```

### Handle Iframes

```typescript
// Locate iframe and interact
const frame = page.frameLocator('iframe[title="Payment"]');
await frame.getByLabel('Card number').fill('4242424242424242');
```

### Handle File Uploads

```typescript
await page.getByLabel('Upload file').setInputFiles('path/to/file.pdf');

// Multiple files
await page.getByLabel('Upload').setInputFiles([
  'file1.pdf',
  'file2.pdf',
]);

// Upload from buffer
await page.getByLabel('Upload').setInputFiles({
  name: 'test.txt',
  mimeType: 'text/plain',
  buffer: Buffer.from('file content'),
});
```

### Handle Downloads

```typescript
const downloadPromise = page.waitForEvent('download');
await page.getByRole('link', { name: 'Download' }).click();
const download = await downloadPromise;

// Save download
await download.saveAs('/path/to/save/file');

// Get download info
console.log(download.suggestedFilename());
```

### Handle Dialogs (Alerts/Confirms)

```typescript
page.on('dialog', async dialog => {
  console.log(dialog.message());
  await dialog.accept(); // or dialog.dismiss()
});

await page.getByRole('button', { name: 'Delete' }).click();
```

### Network Interception

```typescript
// Mock API response
await page.route('**/api/users', async route => {
  await route.fulfill({
    status: 200,
    body: JSON.stringify({ users: [] }),
  });
});

// Wait for API call
const response = await page.waitForResponse('**/api/users');
const data = await response.json();
```

### Parallel Execution Control

```typescript
// Run tests in series within file
test.describe.configure({ mode: 'serial' });

// Run specific test alone
test.describe.configure({ mode: 'parallel' });
test.only('critical test', async ({ page }) => {
  // ...
});
```

## Debugging Tests

### Debug Mode

```bash
# Debug with Playwright Inspector
npx playwright test --debug

# Debug specific test
npx playwright test login.spec.ts --debug

# Debug from specific line (in code)
await page.pause(); // Pauses execution
```

### Trace Viewer

```bash
# Record trace
npx playwright test --trace on

# Open trace
npx playwright show-trace trace.zip
```

### UI Mode (Interactive)

```bash
# Open UI mode for test development
npx playwright test --ui
```

### Verbose Logging

```typescript
// In test
test('with logging', async ({ page }) => {
  page.on('console', msg => console.log('Browser console:', msg.text()));
  page.on('pageerror', err => console.log('Page error:', err));
  page.on('request', req => console.log('Request:', req.url()));
  page.on('response', res => console.log('Response:', res.url()));
});
```

## Performance Optimization

### Parallelize Smartly

```typescript
// playwright.config.ts
export default defineConfig({
  // Run tests in parallel by default
  fullyParallel: true,

  // Limit workers on resource-constrained CI
  workers: process.env.CI ? 2 : undefined,
});
```

### Reduce Waits

```typescript
// ❌ SLOW: Loading full page
await page.goto('https://example.com');

// ✅ FASTER: Wait only for DOM content
await page.goto('https://example.com', {
  waitUntil: 'domcontentloaded'
});

// ✅ FASTEST: Don't wait (if you'll wait for specific element anyway)
await page.goto('https://example.com', {
  waitUntil: 'commit'
});
await page.getByRole('heading').waitFor();
```

### Reuse Authentication

Use storage state to skip login in every test (shown in Authentication section).

### Use Test Sharding on CI

```bash
# Run tests in 4 shards
npx playwright test --shard=1/4
npx playwright test --shard=2/4
npx playwright test --shard=3/4
npx playwright test --shard=4/4
```

## Output & Deliverables

When generating tests:

1. **Create properly structured test files** in appropriate directories
2. **Include comments** explaining complex logic or business rules
3. **Add README** if creating new test suite with setup instructions
4. **Configure playwright.config.ts** if not already present
5. **Provide run commands** and any necessary environment variables

Example output structure:
```
tests/
  ├── pages/
  │   ├── LoginPage.ts
  │   └── DashboardPage.ts
  ├── fixtures/
  │   └── auth.ts
  ├── login.spec.ts
  └── dashboard.spec.ts
playwright.config.ts
.env.example
README.md
```

## Anti-Patterns to Avoid

1. ❌ **Using CSS selectors as primary strategy** → Use semantic locators
2. ❌ **Fixed waits (waitForTimeout)** → Use auto-waiting assertions
3. ❌ **Not isolating tests** → Each test should be independent
4. ❌ **Testing implementation details** → Test user-visible behavior
5. ❌ **No error handling** → Add try-catch and proper logging
6. ❌ **Hardcoding URLs** → Use baseURL and environment variables
7. ❌ **Duplicate code** → Use fixtures and page objects
8. ❌ **No visual regression** → Add screenshot tests for critical pages
9. ❌ **Assertions in page objects** → Keep page objects for actions only
10. ❌ **Ignoring accessibility** → Use getByRole for better coverage

## Quick Reference Commands

```bash
# Install Playwright
npm init playwright@latest

# Run all tests
npx playwright test

# Run specific test file
npx playwright test login.spec.ts

# Run tests in headed mode
npx playwright test --headed

# Run tests in UI mode
npx playwright test --ui

# Run tests in debug mode
npx playwright test --debug

# Generate test
npx playwright codegen https://example.com

# Show report
npx playwright show-report

# Update snapshots
npx playwright test --update-snapshots

# Install browsers
npx playwright install

# Run specific project
npx playwright test --project=chromium

# Run tests matching pattern
npx playwright test -g "login"
```

## Additional Resources

For advanced topics, refer to:
- `{baseDir}/references/` - Extended documentation on advanced patterns
- `{baseDir}/scripts/` - Helper scripts for common automation tasks
- Official docs: https://playwright.dev

## Success Criteria

A well-written Playwright test should:
- ✅ Use semantic locators (getByRole, getByLabel)
- ✅ Include clear, auto-waiting assertions
- ✅ Be independent and isolated
- ✅ Have proper error handling
- ✅ Run reliably across environments
- ✅ Be readable and maintainable
- ✅ Follow the single responsibility principle
- ✅ Include visual regression for critical flows

Remember: Write tests that would make sense to a new team member reading them 6 months from now.
