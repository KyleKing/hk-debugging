# Playwright Testing & Automation Skill

A comprehensive Claude Code skill for Playwright browser automation and testing, following 2025 best practices.

## Overview

This skill provides expert guidance for:
- Writing robust Playwright tests
- Implementing Page Object Model
- Configuring fixtures and test setup
- Visual regression testing
- Debugging and optimization
- Modern locator strategies
- API testing with Playwright

## Installation

### As a Project Skill

```bash
# Copy to your project
cp -r .claude/skills/playwright .claude/skills/

# Or create a symlink
ln -s /path/to/this/skill .claude/skills/playwright
```

### Verification

The skill will be automatically available when working in this project. Claude will invoke it when you ask about Playwright testing.

## How to Use

Simply ask Claude for Playwright-related help:

```
"Create a Playwright test for the login flow"
"Help me debug this failing test"
"Set up Page Object Model for my app"
"Add visual regression testing"
"Configure Playwright for CI/CD"
```

Claude will automatically invoke this skill and provide expert guidance following best practices.

## Skill Structure

```
playwright/
├── SKILL.md                    # Main skill prompt (auto-loaded by Claude)
├── README.md                   # This file
├── references/
│   └── advanced-patterns.md    # Extended documentation for complex scenarios
└── scripts/
    └── generate-test-template.js   # Helper script for test scaffolding
```

## Key Features

### Semantic Locator Strategy

The skill prioritizes user-facing, accessibility-based locators:

1. `getByRole()` - Primary method (accessibility-based)
2. `getByLabel()` - For form inputs
3. `getByPlaceholder()` - For input hints
4. `getByText()` - For visible text
5. `getByTestId()` - Fallback for complex UIs
6. CSS/XPath - Last resort only

### Page Object Model Support

Guides you through creating maintainable page objects:

```typescript
// Automatically generates structure like:
pages/
  ├── LoginPage.ts
  ├── DashboardPage.ts
  └── components/
      └── Header.ts
```

### Visual Regression Testing

Built-in support for screenshot comparison and drift detection:

```typescript
// Generates tests with visual assertions
await expect(page).toHaveScreenshot('homepage.png');
await expect(page.getByTestId('header')).toHaveScreenshot('header.png', {
  maxDiffPixels: 100,
});
```

### Modern Best Practices

- Auto-waiting assertions (no fixed timeouts)
- Parallel test execution
- Proper error handling
- Test isolation and independence
- CI/CD optimization
- Performance testing
- Accessibility testing

## Quick Examples

### Generate a Simple Test

Ask Claude:
```
"Create a test that verifies the homepage loads and has a login button"
```

Result:
```typescript
import { test, expect } from '@playwright/test';

test('homepage loads with login button', async ({ page }) => {
  await page.goto('/');
  await expect(page).toHaveTitle(/Home/);
  await expect(page.getByRole('button', { name: 'Login' })).toBeVisible();
});
```

### Generate Page Object Model

Ask Claude:
```
"Set up Page Object Model for the login page"
```

Result:
```typescript
// pages/LoginPage.ts
export class LoginPage {
  constructor(page: Page) {
    this.page = page;
    this.emailInput = page.getByLabel('Email');
    this.passwordInput = page.getByLabel('Password');
    this.submitButton = page.getByRole('button', { name: 'Sign in' });
  }

  async login(email: string, password: string) {
    await this.emailInput.fill(email);
    await this.passwordInput.fill(password);
    await this.submitButton.click();
  }
}
```

### Configure Custom Fixtures

Ask Claude:
```
"Create a fixture that provides an authenticated user"
```

Result:
```typescript
export const test = base.extend({
  authenticatedPage: async ({ page }, use) => {
    const loginPage = new LoginPage(page);
    await loginPage.goto();
    await loginPage.login('user@example.com', 'password');
    await use(page);
  },
});
```

## Advanced Usage

### API Testing

The skill covers API testing with Playwright's `request` fixture:

```
"Show me how to test the user API endpoint"
```

### Network Mocking

```
"Mock the API response for the users endpoint"
```

### Visual Regression Across Viewports

```
"Test the homepage on mobile, tablet, and desktop"
```

### Accessibility Testing

```
"Add accessibility testing to my Playwright suite"
```

## Helper Scripts

### Generate Test Template

```bash
node .claude/skills/playwright/scripts/generate-test-template.js login
node .claude/skills/playwright/scripts/generate-test-template.js dashboard --pom
```

This creates:
- Test file with proper structure
- Page object (if `--pom` flag used)
- Placeholder for your specific logic

## Configuration Guidance

The skill provides complete `playwright.config.ts` setup including:

- Multi-browser testing (Chromium, Firefox, WebKit)
- Mobile device emulation
- Screenshot/video capture on failure
- Trace collection for debugging
- Parallel execution optimization
- CI/CD specific settings
- Web server auto-start

## Best Practices Enforced

### ✅ Do's

- Use semantic locators (`getByRole`, `getByLabel`)
- Write user-centric tests
- Leverage auto-waiting assertions
- Implement proper error handling
- Use fixtures for setup/teardown
- Add visual regression for critical flows
- Test isolation and independence

### ❌ Don'ts

- Fixed waits (`waitForTimeout`)
- CSS selectors as primary strategy
- Testing implementation details
- Duplicate code across tests
- Hardcoded values
- Assertions in page objects
- Tests that depend on each other

## Debugging Support

The skill provides guidance for:

- Playwright Inspector (`--debug`)
- Trace Viewer (`--trace on`)
- UI Mode (`--ui`)
- Verbose logging
- Screenshot capture
- Video recording
- Network analysis

## CI/CD Integration

Includes patterns for:

- GitHub Actions
- GitLab CI
- Docker containers
- Test sharding
- Parallel execution
- Artifact storage
- Report publishing

## Resources

### References

- `references/advanced-patterns.md` - Deep dive into complex scenarios:
  - API testing
  - Network interception
  - Component testing
  - Accessibility testing
  - Performance testing
  - Mobile testing
  - Database integration

### External Links

- [Official Playwright Docs](https://playwright.dev)
- [Playwright GitHub](https://github.com/microsoft/playwright)
- [Best Practices Guide](https://playwright.dev/docs/best-practices)

## Version Compatibility

This skill follows Playwright best practices as of 2025 and is compatible with:

- Playwright 1.40+
- Node.js 18+
- TypeScript 5+

## Contributing

To enhance this skill:

1. Update `SKILL.md` with new patterns
2. Add examples to `references/advanced-patterns.md`
3. Create helper scripts in `scripts/` for common tasks
4. Update this README with new features

## License

This skill is provided as-is for use with Claude Code. Modify and distribute freely.

## Changelog

### v1.0.0 (2025-11-23)
- Initial release
- Comprehensive testing patterns
- Page Object Model support
- Visual regression testing
- Advanced patterns reference
- Test template generator script
- CI/CD configuration guidance

---

**Need help?** Just ask Claude! This skill is model-invoked, meaning Claude will automatically use it when you ask Playwright-related questions.
