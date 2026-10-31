# Ubuntu font, weight 300

The app's page uses the Ubuntu font. These files are bundled with the app, so the page makes no request to Google Fonts (#137).

- **Source:** the npm package `@fontsource/ubuntu` 5.3.0, released 2026-07-19, checked against its npm integrity `sha512-LsjJXgE430QLs8LKfn1RIFbbdGAiZBU1gao8ASa4Z2kGNGh7lMb7Rzx09v3bLLuuK+3XA/JSLgPWTAbLD6r1fg==`.
- **Licence:** the Ubuntu Font Licence 1.0, in `LICENCE.txt`. It allows the fonts to be bundled and redistributed, unmodified, with that licence and the copyright notice.
- **Files:** one per character subset. `main.css` gives each its `unicode-range`, so a browser downloads only the subsets a page needs.

| File | SHA-256 |
|---|---|
| `ubuntu-cyrillic-300-normal.woff2` | `5b04c8858d97ec108f1d933a9087adcd963f9dda04bb66b67ed0c6db9771f972` |
| `ubuntu-cyrillic-ext-300-normal.woff2` | `098f25fb528179189e436e7d7573d36983358cff726ac889993fd97ba823f017` |
| `ubuntu-greek-300-normal.woff2` | `677a1561e483029490af2dd6fddac39d71b18d4ddc3a90ca26fdd1c2ff42ce37` |
| `ubuntu-greek-ext-300-normal.woff2` | `deb455db2dd20bba526c608c566d441cd405045c1148a08e7262701cfb9c0a11` |
| `ubuntu-latin-300-normal.woff2` | `998fb9fd2f2845f623afa3fad936a4c832f7213cbb153450ff2908088ca418b4` |
| `ubuntu-latin-ext-300-normal.woff2` | `1ec5bd1468d2c2f226d6c4c187a95bfe9e997bd0f15f42114293ea5c0260a012` |

To update: take a newer version of the package that is at least 7 days old (AGENTS.md rule 8), check its integrity, copy the weight-300 `.woff2` files and the licence, and update this table and the `unicode-range` values in `main.css` from the package's `300.css`.
