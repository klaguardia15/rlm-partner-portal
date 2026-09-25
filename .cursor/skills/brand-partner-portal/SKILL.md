# Brand Partner Portal

Rebrand an existing Partner Central site from a logo and a primary image, and keep both partner motions: call-off from a Sales Agreement, and configure-and-quote that requests a price concession.

## Quick Rules

1. Collect three inputs: logo file, primary image, and brand name. The brand name is only for headings and the footer. Colors come from the images.
2. Run `scripts/brand_portal.py`. Do not hand-edit the retrieved Experience bundle.
3. Discover the Experience bundle and NetworkBranding in the target org. Pass `--experience-bundle` or `--network` only when the org has more than one.
4. Do not deploy Network metadata (`*.network-meta.xml`).

## DO NOT

- Do not deploy `*.network-meta.xml`. A retrieved network in UnderConstruction status takes a live site down.
- Do not hardcode a bundle name such as `rlm1` or a branding member such as `cbrlm` as the only path. Those names are the worked example in `examples/zebra/`, not the procedure.
- Do not replace call-off or configure-and-quote with a different page. The script re-asserts both.
- Do not invent a primary color when the images can be sampled. Use `--accent` or `--header` only when the user overrides the sample.

## Entry Conditions

Use this skill when someone wants to rebrand Partner Central, drop in a logo and hero image, or repeat the sales-agreement call-off plus configure-and-quote portal for another brand.

| Task | Use this skill? |
|---|---|
| Upload a logo and primary image and restyle the portal | Yes |
| Change SKUs, margin bands, or the Deal Desk agent | No. That is the `rlm-deal-desk` repo. |
| Create the Partner Central site from scratch | No. The site must already be published. |

## What the script derives

`scripts/brand_portal.py` samples the primary image (and the logo when the hero is dark and low-saturation):

- Accent: the most saturated prominent color. If the hero has almost no saturation, the accent comes from the logo. If neither is saturated, the accent stays Salesforce blue `#0176D3`.
- Header: the darkest prominent color. A dark, low-saturation hero uses a light header and dark text.
- Hover: the accent darkened slightly.

It then retrieves the live Experience bundle, writes content assets `PartnerLogo` and `PartnerPrimary`, patches the branding set, theme `customCSS`, NetworkBranding colors, home, and login, and re-places:

- My Account → `c:rlmPartnerPulse`
- Sales Agreement detail → `c:rlmPartnerAgreement` (embeds `c:rlmPartnerCallOff`)
- Quote list → `c:rlmPartnerStartQuote`
- Quote detail → `c:rlmPartnerQuote`

Call-off still creates the order through foundations `RLM_MFG_SalesAgreementRLMOrder`. This repo does not vendor that class.

## Examples

Worked example — Zebra lime `#A8F932` on black, wordmarks in `examples/zebra/`. Substitute the files you were given.

```bash
pip install -r scripts/requirements.txt
python scripts/brand_portal.py \
  --target-org <sf-alias> \
  --logo ./logo.png \
  --primary-image ./hero.jpg \
  --brand-name "Northwind"
```

Preview the palette without deploying:

```bash
python scripts/brand_portal.py \
  --target-org <sf-alias> \
  --logo ./logo.png \
  --primary-image ./hero.jpg \
  --brand-name "Northwind" \
  --sample-only
```

When the org has a single Experience bundle and a single Network, omit `--experience-bundle` and `--network`. The script lists metadata and uses the only match. Partner Central (Enhanced) branding files are usually `partnerCentralEnhanced.json`; if that file is absent and the folder has one JSON file, that file is used.

## Validation Checks

1. `python scripts/brand_portal.py ... --sample-only` prints a palette with `accent` and `header`.
2. After deploy, the branding set `CompanyLogo` points at `/file-asset/PartnerLogo` and `LoginBackgroundImage` points at `/file-asset/PartnerPrimary`.
3. Sales Agreement detail contains `c:rlmPartnerAgreement`. Quote detail contains `c:rlmPartnerQuote`.
4. The deploy log does not include a Network metadata file.
5. Publish the site (`sf community publish`) only after the Experience deploy succeeds. The script does this unless `--skip-publish` is set.
