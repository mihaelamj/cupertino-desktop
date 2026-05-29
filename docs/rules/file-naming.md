# File Naming Rules

Conventions for naming committed files in the Tiledown repo: lowercase, dash-separated, ASCII, ISO dates.

Every file committed must follow these conventions.

## General Rules

- **Lowercase only**: no uppercase letters in filenames.
- **Dashes for separators**: use `-` instead of spaces, underscores, or camelCase.
- **No spaces**: ever.
- **No special characters**: no accented letters, `()`, `[]`, `&`. Transliterate accented characters to plain ASCII (for example c-with-caron to `c`, s-with-caron to `s`, d-with-stroke to `dj`).
- **No trailing dots**: remove dots before the file extension.
- **ASCII only**: filenames must be plain ASCII.

## Date Format in Filenames

Always use ISO format: `YYYY-MM-DD`

- `30.11.2023` -> `2023-11-30`
- `11.03.2024.` -> `2024-03-11`
- `Mar 24, 2025` -> `2025-03-24`

## Document Naming Patterns

### Scanned documents
```
Scan MMM DD, YYYY at HH.MM.pdf    -> scan-YYYY-MM-DD-HH-MM.pdf
Scan DD.MM.YYYY. at HH.MM.pdf     -> scan-YYYY-MM-DD-HH-MM.pdf
Scan DD MMM YYYY at HH.MM.pdf     -> scan-YYYY-MM-DD-HH-MM.pdf
```

### Photos
```
IMG_XXXX.jpeg                      -> keep as-is (acceptable)
IMG_XXXX.HEIC                      -> convert to IMG_XXXX.jpg (sips)
Photo DD-MM-YYYY.heic              -> photo-YYYY-MM-DD.jpg (convert + rename)
```

### Dated documents
```
<type>-<description>-YYYY-MM-DD.pdf
```
Use a date suffix only when the document is date-specific; omit it otherwise.

## Renaming Existing Files

When renaming, always use `git mv` to preserve history:
```bash
git mv "Old File Name.pdf" "old-file-name.pdf"
```

Commit: `rename: normalize filenames`

## Audit (before any processing)

Run these in the repo before reporting counts:

```bash
# Files with spaces
find <repo> -name "* *" -not -path "*/.git/*" -not -name "*.md"

# Files with uppercase
find <repo> -regex ".*/[^/]*[A-Z][^/]*" -not -path "*/.git/*" -not -name "README*" -not -name "*.md"

# Files with underscores (excluding .git)
find <repo> -name "*_*" -not -path "*/.git/*" -not -name "*.md"

# HEIC files
find <repo> \( -name "*.heic" -o -name "*.HEIC" \) -not -path "*/.git/*"
```

## Skip List

Some asset paths legitimately carry vendor-supplied names and are exempt from the audit. Document the skip paths per repo (for example `*/webAccessibleResources/*`, generated id-document folders, vendor photo dumps). Keep the list short and justified.
