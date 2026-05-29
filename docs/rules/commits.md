# Git Commit Framework

The commit-message format for Tiledown: Conventional Commits, imperative mood, one logical change per commit.

Create meaningful, consistent git commits following the Conventional Commits specification. Every commit must clearly communicate the what, why, and impact of changes for collaboration and automated tooling.

## Core rules

### Rule 1: Commit format

Use this exact format:
```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```
- MUST use lowercase for type
- MUST use present tense, imperative mood
- MUST NOT end description with period
- MUST limit first line to 72 characters

### Rule 2: Commit types

Select the correct type:
- `feat`: New feature or functionality
- `fix`: Bug fix or error correction
- `docs`: Documentation changes only
- `style`: Code style/formatting (no logic change)
- `refactor`: Code restructuring (no behavior change)
- `perf`: Performance improvements
- `test`: Test additions or corrections
- `build`: Build system or dependencies
- `ci`: CI/CD configuration changes
- `chore`: Maintenance tasks

### Rule 3: Breaking changes

Indicate breaking changes:
- MUST add `!` after type/scope for breaking changes
- MUST include `BREAKING CHANGE:` in footer
- MUST explain migration path

### Rule 4: Commit scope

Include relevant scope:
- Use component/module name
- Use feature area
- Keep consistent across project
- Omit only if change is truly global

## Commit type decision tree

```
What kind of change are you making?
|- Adding new capability?
|   |- User-facing feature? -> feat
|   |- Developer tool? -> build/chore
|   +- Test coverage? -> test
|- Fixing something broken?
|   |- Bug in code? -> fix
|   |- Typo in docs? -> docs
|   +- Test failure? -> test/fix
|- Changing existing code?
|   |- Improving performance? -> perf
|   |- Restructuring code? -> refactor
|   |- Formatting only? -> style
|   +- Updating dependencies? -> build
+- Project maintenance?
    |- CI/CD changes? -> ci
    |- Documentation? -> docs
    +- Other tasks? -> chore
```

## Commit message patterns

### Pattern 1: Feature commits

```bash
# RULE: New features require clear user benefit
feat(auth): add OAuth2 authentication support

# RULE: Include implementation details in body
feat(api): implement rate limiting for API endpoints

Adds configurable rate limiting using Redis:
- 100 requests per minute for anonymous users
- 1000 requests per minute for authenticated users
- Customizable limits per API key

Closes #234
```

### Pattern 2: Bug fix commits

```bash
# RULE: Describe what was broken and now works
fix(parser): handle empty input without crashing

# RULE: Reference issue numbers
fix(ui): correct button alignment on mobile devices

The submit button was overlapping with the cancel button
on screens smaller than 375px. Added proper flex spacing.

Fixes #456
```

### Pattern 3: Breaking change commits

```bash
# RULE: Use ! and BREAKING CHANGE footer
feat(api)!: change authentication from cookies to JWT tokens

BREAKING CHANGE: API now requires Bearer token authentication.
Cookie-based auth has been removed. Update clients to send
Authorization header with JWT token.

Migration guide: https://docs.example.com/migration/v2
```

### Pattern 4: Refactoring commits

```bash
# RULE: Explain why, not just what
refactor(database): extract query builder into separate class

Improves testability and reduces coupling between
repository and database layers. No functional changes.

# RULE: Keep behavior identical
refactor(utils): use native Array methods instead of lodash

Removes lodash dependency for array operations.
All tests pass without modification.
```

### Pattern 5: Documentation commits

```bash
# RULE: Be specific about what was documented
docs(readme): add installation instructions for Windows

# RULE: Include scope for API docs
docs(api): document rate limiting headers and status codes
```

### Pattern 6: Performance commits

```bash
# RULE: Include metrics when possible
perf(search): optimize full-text search query

Reduces search time from ~500ms to ~50ms by adding
compound index on (title, content, created_at).

Benchmark results:
- Before: 487ms avg (n=1000)
- After: 52ms avg (n=1000)
```

## Commit scope guidelines

### Scope selection strategy

```markdown
# RULE: Use consistent, meaningful scopes
Common scope patterns:
- Component name: (Button), (Modal), (Form)
- Feature area: (auth), (payment), (search)
- Layer: (api), (db), (ui), (service)
- File type: (config), (types), (tests)

# RULE: Omit scope only for truly global changes
Examples when to omit:
- Project-wide dependency updates
- Global configuration changes
- Cross-cutting refactors
```

### Multi-file changes

```bash
# RULE: Use most specific common scope
# Changed: auth/login.ts, auth/logout.ts, auth/session.ts
feat(auth): add session timeout handling

# RULE: Use general scope for many areas
# Changed: multiple unrelated files
refactor: update imports to use path aliases
```

## Commit body guidelines

### When to include a body

```markdown
Include body when:
- Change requires explanation
- Multiple issues addressed
- Breaking changes introduced
- Performance metrics available
- Complex implementation details
- External references needed
```

### Body format rules

```bash
# RULE: Wrap at 72 characters
# RULE: Separate body from subject with blank line
# RULE: Use bullet points for multiple items

fix(cache): prevent memory leak in LRU cache implementation

- Add proper cleanup in cache eviction
- Implement WeakMap for object references
- Add memory limit configuration option

The previous implementation held strong references to evicted
items, preventing garbage collection. This change ensures
proper memory management while maintaining O(1) operations.

Fixes #789
```

## Commit footer patterns

### Issue references

```bash
# RULE: Use correct keywords
fix(api): validate input before processing

Fixes #123        # Closes the issue
Closes #456       # Also closes the issue
Resolves #789     # Also closes the issue
See #101          # References without closing
Related to #102   # References without closing
```

### Co-authors

```bash
# RULE: Credit all human contributors
feat(ui): implement dark mode toggle

Pair programmed the CSS architecture and state management.

Co-authored-by: Jane Doe <jane@example.com>
Co-authored-by: Bob Smith <bob@example.com>
```

### Review references

```bash
# RULE: Link to code review discussions
refactor(engine): simplify state machine logic

See detailed discussion in PR #234 about the
approach and alternatives considered.

Reviewed-by: Alice Johnson <alice@example.com>
```

## Commit validation checklist

Before committing, verify:

- [ ] Type is correct (feat/fix/docs/etc.)
- [ ] Scope reflects affected area
- [ ] Description in imperative mood
- [ ] Description under 72 characters
- [ ] No period at end of description
- [ ] Breaking changes marked with !
- [ ] BREAKING CHANGE footer if needed
- [ ] Body explains why (not just what)
- [ ] Body wrapped at 72 characters
- [ ] Issue references use correct keywords
- [ ] Co-authors credited properly
- [ ] Commit is atomic (one logical change)
- [ ] All tests pass
- [ ] No debug code or stray logging

## Common mistakes to avoid

### DON'T: Use past tense
```bash
# WRONG
feat(auth): added login functionality

# RIGHT
feat(auth): add login functionality
```

### DON'T: Be vague
```bash
# WRONG
fix: fix bug
chore: update stuff
refactor: changes

# RIGHT
fix(parser): handle null input in JSON parser
chore(deps): update React from 17.0.2 to 18.2.0
refactor(auth): extract token validation to middleware
```

### DON'T: Combine unrelated changes
```bash
# WRONG
feat(ui): add dark mode and fix login bug and update deps

# RIGHT, split into separate commits:
feat(ui): add dark mode toggle
fix(auth): resolve login redirect issue
build(deps): update React and TypeScript
```

### DON'T: Forget breaking change notation
```bash
# WRONG
feat(api): change response format

# RIGHT
feat(api)!: change response format to follow JSON:API spec

BREAKING CHANGE: API responses now use JSON:API format.
Old format: { data: [...] }
New format: { data: [...], meta: {}, links: {} }
```

## Integration with tools

### Commitlint configuration

```javascript
// RULE: Enforce rules automatically
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'scope-enum': [2, 'always', [
      'api', 'auth', 'build', 'ci', 'core',
      'db', 'deps', 'docs', 'ui', 'utils'
    ]],
    'body-max-line-length': [2, 'always', 72],
    'header-max-length': [2, 'always', 72]
  }
};
```

## Branch naming rules

### Branch name format

```bash
# RULE: Use consistent branch naming
<type>/<ticket>-<brief-description>

# Examples:
feat/123-add-oauth-support
fix/456-resolve-memory-leak
chore/update-dependencies
release/v2.0.0
hotfix/critical-security-patch
```

### Branch type mapping

```markdown
Branch types should match commit types:
- feat/* -> Feature branches
- fix/* -> Bug fix branches
- docs/* -> Documentation updates
- refactor/* -> Code refactoring
- test/* -> Test additions
- chore/* -> Maintenance tasks
```

See docs/rules/git-discipline.md for branch, PR, label, and remote conventions that build on this format.
