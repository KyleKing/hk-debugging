# Advanced Playwright Patterns & Techniques

## API Testing with Playwright

Playwright can test APIs directly, making it excellent for comprehensive E2E testing.

### Basic API Testing

```typescript
import { test, expect } from '@playwright/test';

test('API: get user data', async ({ request }) => {
  const response = await request.get('https://api.example.com/users/1');

  expect(response.ok()).toBeTruthy();
  expect(response.status()).toBe(200);

  const user = await response.json();
  expect(user).toHaveProperty('id', 1);
  expect(user).toHaveProperty('email');
});
```

### API + UI Testing Combined

```typescript
test('create user via API, verify in UI', async ({ request, page }) => {
  // Create user via API
  const response = await request.post('https://api.example.com/users', {
    data: {
      name: 'Test User',
      email: 'test@example.com',
    },
  });

  const user = await response.json();

  // Verify in UI
  await page.goto(`/users/${user.id}`);
  await expect(page.getByText(user.name)).toBeVisible();
});
```

### API Authentication & Headers

```typescript
test.use({
  extraHTTPHeaders: {
    'Authorization': `Bearer ${process.env.API_TOKEN}`,
    'Accept': 'application/json',
  },
});

test('authenticated API request', async ({ request }) => {
  const response = await request.get('/api/protected');
  expect(response.ok()).toBeTruthy();
});
```

## Advanced Network Control

### Modify Requests

```typescript
test('modify request headers', async ({ page }) => {
  await page.route('**/*', async (route) => {
    const headers = {
      ...route.request().headers(),
      'X-Custom-Header': 'test-value',
    };
    await route.continue({ headers });
  });

  await page.goto('https://example.com');
});
```

### Mock API Responses

```typescript
test('mock API with different scenarios', async ({ page }) => {
  // Mock successful response
  await page.route('**/api/users', async (route) => {
    if (route.request().method() === 'GET') {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          users: [
            { id: 1, name: 'Alice' },
            { id: 2, name: 'Bob' },
          ],
        }),
      });
    }
  });

  await page.goto('/users');
  await expect(page.getByText('Alice')).toBeVisible();
});

test('mock API error', async ({ page }) => {
  await page.route('**/api/users', async (route) => {
    await route.fulfill({
      status: 500,
      contentType: 'application/json',
      body: JSON.stringify({ error: 'Server error' }),
    });
  });

  await page.goto('/users');
  await expect(page.getByText('Error loading users')).toBeVisible();
});
```

### Record and Replay Network

```typescript
// Record HAR file
test('record network traffic', async ({ page }) => {
  await page.routeFromHAR('./hars/example.har', {
    url: '**/api/**',
    update: true, // Record mode
  });

  await page.goto('https://example.com');
});

// Replay from HAR
test('replay from HAR', async ({ page }) => {
  await page.routeFromHAR('./hars/example.har', {
    url: '**/api/**',
  });

  await page.goto('https://example.com');
  // API calls will be served from HAR file
});
```

## Component Testing

Test individual components in isolation.

```typescript
import { test, expect } from '@playwright/experimental-ct-react';
import { Button } from './Button';

test('button click', async ({ mount }) => {
  let clicked = false;
  const component = await mount(
    <Button onClick={() => clicked = true}>Click me</Button>
  );

  await component.click();
  expect(clicked).toBeTruthy();
});
```

## Accessibility Testing

```typescript
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test('accessibility scan', async ({ page }) => {
  await page.goto('https://example.com');

  const accessibilityScanResults = await new AxeBuilder({ page })
    .analyze();

  expect(accessibilityScanResults.violations).toEqual([]);
});

test('focused accessibility scan', async ({ page }) => {
  await page.goto('https://example.com');

  const accessibilityScanResults = await new AxeBuilder({ page })
    .include('#main-content')
    .exclude('#ads')
    .withTags(['wcag2a', 'wcag2aa'])
    .analyze();

  expect(accessibilityScanResults.violations).toEqual([]);
});
```

## Performance Testing

### Measure Web Vitals

```typescript
test('measure web vitals', async ({ page }) => {
  await page.goto('https://example.com');

  const vitals = await page.evaluate(() => {
    return new Promise((resolve) => {
      const metrics = {};

      new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) {
          if (entry.name === 'first-contentful-paint') {
            metrics.fcp = entry.startTime;
          }
        }
      }).observe({ entryTypes: ['paint'] });

      new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) {
          metrics.lcp = entry.startTime;
        }
        resolve(metrics);
      }).observe({ entryTypes: ['largest-contentful-paint'] });
    });
  });

  console.log('Web Vitals:', vitals);
  expect(vitals.lcp).toBeLessThan(2500); // Good LCP < 2.5s
});
```

### Network Throttling

```typescript
import { test, chromium } from '@playwright/test';

test('test under slow network', async () => {
  const browser = await chromium.launch();
  const context = await browser.newContext();

  // Simulate slow 3G
  await context.route('**/*', async (route) => {
    await new Promise(resolve => setTimeout(resolve, 100)); // Add 100ms delay
    await route.continue();
  });

  const page = await context.newPage();
  await page.goto('https://example.com');

  // Test behavior under slow network
  await expect(page.getByText('Loading...')).toBeVisible();
});
```

## Multi-Tab & Multi-Window Testing

```typescript
test('handle new tab', async ({ page, context }) => {
  await page.goto('https://example.com');

  // Listen for new page
  const pagePromise = context.waitForEvent('page');
  await page.getByRole('link', { name: 'Open in new tab' }).click();

  const newPage = await pagePromise;
  await newPage.waitForLoadState();

  await expect(newPage).toHaveURL(/new-page/);
  await newPage.close();
});

test('work with multiple pages', async ({ context }) => {
  const page1 = await context.newPage();
  const page2 = await context.newPage();

  await page1.goto('https://example.com/page1');
  await page2.goto('https://example.com/page2');

  // Work with both pages
  await expect(page1.getByRole('heading')).toHaveText('Page 1');
  await expect(page2.getByRole('heading')).toHaveText('Page 2');
});
```

## Mobile-Specific Testing

```typescript
import { test, devices } from '@playwright/test';

test.use({
  ...devices['iPhone 13'],
});

test('mobile geolocation', async ({ page, context }) => {
  await context.setGeolocation({ latitude: 40.7128, longitude: -74.0060 });
  await context.grantPermissions(['geolocation']);

  await page.goto('https://maps.example.com');
  await page.getByRole('button', { name: 'Use my location' }).click();

  await expect(page.getByText('New York')).toBeVisible();
});

test('mobile touch gestures', async ({ page }) => {
  await page.goto('https://example.com');

  // Swipe
  await page.touchscreen.swipe({ x: 100, y: 100 }, { x: 300, y: 100 });

  // Tap
  await page.touchscreen.tap(150, 150);
});
```

## Database Integration

```typescript
import { test } from '@playwright/test';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

test.beforeEach(async () => {
  // Seed database
  await prisma.user.create({
    data: {
      email: 'test@example.com',
      name: 'Test User',
    },
  });
});

test.afterEach(async () => {
  // Clean up
  await prisma.user.deleteMany();
});

test('user can login', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill('test@example.com');
  await page.getByLabel('Password').fill('password');
  await page.getByRole('button', { name: 'Sign in' }).click();

  await expect(page.getByText('Welcome, Test User')).toBeVisible();
});
```

## Advanced Fixtures Patterns

### Worker-Scoped Fixtures

```typescript
import { test as base } from '@playwright/test';

type WorkerFixtures = {
  globalDatabase: Database;
};

const test = base.extend<{}, WorkerFixtures>({
  globalDatabase: [async ({}, use) => {
    // Setup once per worker
    const db = await setupDatabase();
    await use(db);
    await db.close();
  }, { scope: 'worker' }],
});
```

### Automatic Fixtures

```typescript
const test = base.extend({
  // Automatically takes screenshot on failure
  autoScreenshot: [async ({ page }, use, testInfo) => {
    await use();

    if (testInfo.status !== testInfo.expectedStatus) {
      const screenshot = await page.screenshot();
      await testInfo.attach('screenshot', {
        body: screenshot,
        contentType: 'image/png',
      });
    }
  }, { auto: true }],
});
```

## Global Setup & Teardown

```typescript
// global-setup.ts
import { chromium, FullConfig } from '@playwright/test';

async function globalSetup(config: FullConfig) {
  // Start services, seed database, etc.
  console.log('Global setup');

  // Create admin user and save auth state
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.goto('http://localhost:3000/login');
  await page.getByLabel('Email').fill('admin@example.com');
  await page.getByLabel('Password').fill('admin123');
  await page.getByRole('button', { name: 'Sign in' }).click();
  await page.context().storageState({ path: 'admin-auth.json' });
  await browser.close();
}

export default globalSetup;

// global-teardown.ts
async function globalTeardown() {
  // Cleanup
  console.log('Global teardown');
}

export default globalTeardown;

// playwright.config.ts
export default defineConfig({
  globalSetup: require.resolve('./global-setup'),
  globalTeardown: require.resolve('./global-teardown'),
});
```

## Conditional Testing

```typescript
// Skip on specific browsers
test('WebGL test', async ({ page, browserName }) => {
  test.skip(browserName === 'firefox', 'WebGL not working on Firefox');
  // Test WebGL features
});

// Run only on specific conditions
test('desktop-only feature', async ({ page, isMobile }) => {
  test.skip(isMobile, 'Desktop only');
  // Test desktop feature
});

// Conditional execution
test.describe('admin features', () => {
  test.skip(!process.env.ADMIN_TESTS, 'Admin tests disabled');

  test('admin dashboard', async ({ page }) => {
    // Admin test
  });
});
```

## Screenshot Comparison with Regions

```typescript
test('compare specific region', async ({ page }) => {
  await page.goto('https://example.com');

  // Screenshot specific element
  const header = page.getByTestId('header');
  await expect(header).toHaveScreenshot('header.png');

  // Screenshot with clipping
  await expect(page).toHaveScreenshot('clipped.png', {
    clip: { x: 0, y: 0, width: 800, height: 600 },
  });

  // Screenshot with animations disabled
  await expect(page).toHaveScreenshot('no-animations.png', {
    animations: 'disabled',
  });
});
```

## Custom Reporters

```typescript
// custom-reporter.ts
import { Reporter, TestCase, TestResult } from '@playwright/test/reporter';

class CustomReporter implements Reporter {
  onTestEnd(test: TestCase, result: TestResult) {
    console.log(`Finished test ${test.title}: ${result.status}`);

    if (result.status === 'failed') {
      // Send to monitoring service
      sendToMonitoring({
        test: test.title,
        error: result.error,
        duration: result.duration,
      });
    }
  }
}

export default CustomReporter;

// playwright.config.ts
reporter: [['./custom-reporter.ts']],
```

## Docker Integration

```yaml
# docker-compose.yml
version: '3'
services:
  tests:
    image: mcr.microsoft.com/playwright:latest
    volumes:
      - .:/app
    working_dir: /app
    command: npx playwright test
    environment:
      - CI=true
```

```bash
# Run tests in Docker
docker-compose run tests
```

## Debugging Production Issues

```typescript
// Replay production issue locally
test('reproduce production bug #1234', async ({ page }) => {
  // Use production-like data
  await page.route('**/api/**', async (route) => {
    await route.fulfill({
      status: 200,
      body: productionDataSnapshot,
    });
  });

  // Reproduce exact steps
  await page.goto('/dashboard');
  await page.getByRole('button', { name: 'Export' }).click();

  // Verify fix
  await expect(page.getByText('Export complete')).toBeVisible();
});
```

## Tips & Tricks

### Stable Element Location

```typescript
// Wait for element to be stable (stop moving)
await page.getByRole('button').click({ trial: true }); // Dry run
await page.getByRole('button').click(); // Actual click
```

### Custom Expect Matchers

```typescript
import { expect as baseExpect } from '@playwright/test';

export const expect = baseExpect.extend({
  async toHaveValidEmail(locator: Locator) {
    const text = await locator.textContent();
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    const pass = emailRegex.test(text || '');

    return {
      pass,
      message: () => `Expected ${text} to be a valid email`,
    };
  },
});

// Usage
await expect(page.getByTestId('email')).toHaveValidEmail();
```

### Keyboard Shortcuts

```typescript
// Press multiple keys
await page.keyboard.press('Control+A');
await page.keyboard.press('Control+V');

// Type with delay
await page.keyboard.type('Hello World', { delay: 100 });
```

### Mouse Interactions

```typescript
// Hover
await page.getByRole('button').hover();

// Right click
await page.getByRole('button').click({ button: 'right' });

// Double click
await page.getByRole('button').dblclick();

// Click at specific position
await page.click('.target', { position: { x: 10, y: 10 } });
```

These advanced patterns enable sophisticated testing scenarios beyond basic UI automation.
