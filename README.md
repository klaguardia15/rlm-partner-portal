# Partner portal — call-off and configure & quote

Partner Central experience for two motions that show up on the same deal:

1. **Call-off.** The partner opens an activated Sales Agreement and places an order at the contracted price. Actuals post back to that agreement.
2. **Configure and quote.** The partner builds a quote for something that is not on the agreement and sends a price concession to deal desk. List price stays until deal desk applies it.

Deal desk quote compare and the Deal Desk Assistant live in a separate repo: [rlm-deal-desk](https://github.com/klaguardia15/rlm-deal-desk).

## Deploy mechanism (for an AI agent following a deploy prompt)

- **SFDX source deploy** — `sf project deploy start --source-dir force-app`. There is **no** CumulusCI project and **no** `cumulusci.yml`; do not look for one.
- **No data is loaded or deleted** by this repo. The optional branding script (`brand_portal.py`) retrieves, patches, redeploys and **publishes** the Experience site — org *config*, not records. Treat publishing as a mutating step and confirm before running it.
- This repo is **private**. If `git clone https://github.com/klaguardia15/rlm-partner-portal.git` returns 404, that is a GitHub **auth** problem (run `gh auth login` or use SSH), not a missing repo — do not substitute another repo.
- Do **not** deploy Network metadata (`*.network-meta.xml`). None is included; the branding script strips any it retrieves.

## Prerequisites — the metadata deploy FAILS without these

This package does not create the org or the Experience site, and it references components that must
**already exist** in the target org, or `sf project deploy start` errors out before anything lands:

- **Revenue Cloud** quoting and **Product Discovery**.
- **Partner Central (Enhanced)** already published, including the profile the sharing set targets:
  **`RLM Custom Partner Community User`**, and a **Partner Community** license (the permission set is
  licensed to it).
- **Manufacturing Sales Agreements**, including:
  - foundations Apex class **`RLM_MFG_SalesAgreementRLMOrder`** — call-off calls `createOrder` on it
    (compile dependency of `RLM_PartnerAgreements`; it is **not** copied here);
  - foundations flows **`RLM_MFG_Sales_Agreement_Order_Execution`** (a subflow of
    `RLM_Partner_Quick_Quote`, also granted in the permission set) and **`RLM_DiscoverProducts`**
    (granted in the permission set);
  - foundations MFG fields granted by the permission set: `SalesAgreement.RLM_MFG_Contract__c` and
    `SalesAgreementProductSchedule.RLM_MFG_Product_Name__c` / `RLM_MFG_Product2Id__c` /
    `RLM_MFG_PricebookEntryId__c` / `RLM_MFG_SalesAgreementId__c`.
- The **Product Configurator** managed package (namespace `ProductConfig`) — the quick-quote flow
  references `ProductConfig__ConfiguratorContext`.
- A **partner user** on the account that owns the Sales Agreement, with this package's permission set
  and the sharing set activated.

Sharing set `Partner_Account_Sales_Agreements` grants agreements where `SalesAgreement.Account` equals
the partner contact's account.

Everything else the package needs — the `RLM_Partner*` Apex, the three flows, the LWCs, the custom
Quote/SalesAgreementProduct `RLM_*__c` fields, list views, static resources, the permission set, and the
sharing set — ships **in this repo** and deploys together.

## Deploy the package

**Dry-run first** (validate without saving — this is where missing prerequisites surface):

```bash
sf project deploy start --source-dir force-app --dry-run --target-org <sf-alias> --wait 30
```

Then deploy and assign the permission set:

```bash
sf project deploy start --source-dir force-app --target-org <sf-alias> --wait 30
sf org assign permset --name RLM_Partner_Agreements --target-org <sf-alias>
```

`<sf-alias>` is an `sf` CLI alias or username.

That deploy installs the LWCs, Apex, flows, fields, list views, static resources, and sharing set. It does not restyle the site. Branding is the next step.

## Post-deploy checklist

1. **Assign the permission set** — `RLM_Partner_Agreements` (command above). It grants the Apex, flows,
   objects/fields, and tabs the two motions need. Assign it to the partner user(s).
2. **Confirm the sharing set is active** — `Partner_Account_Sales_Agreements`. It deploys, but verify it
   is enabled for the `RLM Custom Partner Community User` profile so partners see only their account's
   agreements.
3. **Brand the site (optional) — see below.** *(Retrieves, patches, redeploys, and publishes the
   Experience site — confirm before running.)*
4. **Verify the pages carry the components** (the brand script asserts these; check by hand if you skip
   branding):

   | Page | Component |
   |---|---|
   | My Account | `rlmPartnerPulse` |
   | My agreements / Sales Agreement | `rlmPartnerAgreement` and `rlmPartnerCallOff` |
   | Quote list | `rlmPartnerStartQuote` |
   | Quote detail | `rlmPartnerQuote` |

Call-off is the on-agreement order. Configure and quote is the off-agreement exception. The concession creates a Task for the account owner. Work that task in the deal-desk repo.

## Brand it from a logo and a primary image

Open this repo in Cursor and ask to brand the partner portal. The procedure is `.cursor/skills/brand-partner-portal/SKILL.md`.

You provide:

- a logo file
- a primary image (login background and home hero)
- the brand name (headings and footer only)

Colors are sampled from the images. The script keeps both motions on the site. It does **not** deploy Network metadata, and it **publishes** the community when it finishes.

```bash
pip install -r scripts/requirements.txt
python scripts/brand_portal.py \
  --target-org <sf-alias> \
  --logo ./logo.png \
  --primary-image ./hero.jpg \
  --brand-name "Northwind"
```

A Zebra color-and-logo example is in `examples/zebra/`. It is not the default theme.

## Safety

Nothing in this repo loads or deletes records. The mutating post-deploy action is the branding script,
which changes and **publishes** the Experience site (config). Confirm before running it.

## Share this repo

The GitHub repo is private. Invite people from the repo page, or:

```bash
gh repo add-collaborator klaguardia15/rlm-partner-portal <github-username>
```

## License

Apache-2.0. See `LICENSE.txt`. Copyright Salesforce, Inc.
