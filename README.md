# Partner portal — call-off and configure & quote

Partner Central experience for two motions that show up on the same deal:

1. **Call-off.** The partner opens an activated Sales Agreement and places an order at the contracted price. Actuals post back to that agreement.
2. **Configure and quote.** The partner builds a quote for something that is not on the agreement and sends a price concession to deal desk. List price stays until deal desk applies it.

Deal desk quote compare and the Deal Desk Assistant live in a separate repo: [rlm-deal-desk](https://github.com/klaguardia15/rlm-deal-desk).

## Prerequisites

This package does not create the org or the Experience site.

- Revenue Cloud quoting and Product Discovery
- Partner Central (Enhanced) already published
- Manufacturing sales agreements, including foundations class `RLM_MFG_SalesAgreementRLMOrder` (call-off calls `createOrder` on that class; it is not copied here)
- A partner user on the account that owns the Sales Agreement, with this package's permission set and the sharing set activated

Sharing set `Partner_Account_Sales_Agreements` grants agreements where `SalesAgreement.Account` equals the partner contact's account.

## Deploy the package

```bash
sf project deploy start --source-dir force-app --target-org <sf-alias> --wait 30
sf org assign permset --name RLM_Partner_Agreements --target-org <sf-alias>
```

`<sf-alias>` is an `sf` CLI alias or username.

That deploy installs the LWCs, Apex, flows, fields, and sharing set. It does not restyle the site. Branding is the next step.

## Brand it from a logo and a primary image

Open this repo in Cursor and ask to brand the partner portal. The procedure is `.cursor/skills/brand-partner-portal/SKILL.md`.

You provide:

- a logo file
- a primary image (login background and home hero)
- the brand name (headings and footer only)

Colors are sampled from the images. The script keeps both motions on the site. It does **not** deploy Network metadata.

```bash
pip install -r scripts/requirements.txt
python scripts/brand_portal.py \
  --target-org <sf-alias> \
  --logo ./logo.png \
  --primary-image ./hero.jpg \
  --brand-name "Northwind"
```

A Zebra color-and-logo example is in `examples/zebra/`. It is not the default theme.

## Pages the brand script asserts

| Page | Component |
|---|---|
| My Account | `rlmPartnerPulse` |
| My agreements / Sales Agreement | `rlmPartnerAgreement` and `rlmPartnerCallOff` |
| Quote list | `rlmPartnerStartQuote` |
| Quote detail | `rlmPartnerQuote` |

Call-off is the on-agreement order. Configure and quote is the off-agreement exception. The concession creates a Task for the account owner. Work that task in the deal-desk repo.

## Share this repo

The GitHub repo is private. Invite people from the repo page, or:

```bash
gh repo add-collaborator klaguardia15/rlm-partner-portal <github-username>
```

## License

Apache-2.0. See `LICENSE.txt`. Copyright Salesforce, Inc.
