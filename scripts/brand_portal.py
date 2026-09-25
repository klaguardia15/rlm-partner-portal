#!/usr/bin/env python3
"""Brand an existing Partner Central site from a logo, a primary image, and a brand name.

Retrieves the live ExperienceBundle and NetworkBranding, patches theme, home, login,
and the two partner motions (sales-agreement call-off and configure-and-quote),
then deploys. Does not deploy Network metadata.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import tempfile
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BRAND_DIR = ROOT / "branding"
FORCE = ROOT / "force-app/main/default"
WORK = ROOT / ".experience-work"
LOGO_ASSET = "PartnerLogo"
PRIMARY_ASSET = "PartnerPrimary"

ACCENT = "#0176D3"
ACCENT_HOVER = "#014486"
ACCENT_DEEP = "#01386A"
HEADER = "#0B1F33"
ON_HEADER = "#FFFFFF"
MUTED = "#5C6770"
BRAND_NAME = "Partner"
LOGO_URL = "/file-asset/PartnerLogo?v=1"
PRIMARY_URL = "/file-asset/PartnerPrimary?v=1"
BUNDLE_NAME = ""
BRANDING_MEMBER = ""
NETWORK_NAME = ""


def _hex_to_rgb(value: str) -> tuple[int, int, int]:
    raw = value.lstrip("#")
    if len(raw) == 3:
        raw = "".join(ch * 2 for ch in raw)
    return int(raw[0:2], 16), int(raw[2:4], 16), int(raw[4:6], 16)


def accent_rgba(alpha: float, color: str | None = None) -> str:
    r, g, b = _hex_to_rgb(color or ACCENT)
    return f"rgba({r}, {g}, {b}, {alpha})"


def accent_rgb(color: str) -> str:
    r, g, b = _hex_to_rgb(color)
    return f"rgb({r}, {g}, {b})"


def render_brand_file(name: str) -> str:
    text = (BRAND_DIR / name).read_text()
    r, g, b = _hex_to_rgb(HEADER)
    tokens = {
        "HEADER": HEADER,
        "ON_HEADER": ON_HEADER,
        "ACCENT": ACCENT,
        "ACCENT_HOVER": ACCENT_HOVER,
        "MUTED": MUTED,
        "FONT": '"IBM Plex Sans", Arial, Helvetica, sans-serif',
        "BRAND_NAME": BRAND_NAME,
        "LOGO_URL": LOGO_URL,
        "PRIMARY_URL": PRIMARY_URL,
        "HEADER_RGBA": f"rgba({r}, {g}, {b}, 0.82)",
    }
    for key, value in tokens.items():
        text = text.replace("{{" + key + "}}", value)
    return text


def build_header_attrs() -> dict:
    return {
        "background": f"background: {HEADER}",
        "backgroundOverlayColor": "rgba(0, 0, 0, 0)",
        "borderBottomColor": HEADER,
        "borderTopColor": HEADER,
        "dropdownBackgroundColor": HEADER,
        "dropdownBackgroundHoverColor": MUTED,
        "dropdownBorderColor": MUTED,
        "dropdownTextColor": ON_HEADER,
        "dropdownTextHoverColor": ACCENT,
        "iconLinkColor": ON_HEADER,
        "iconLinkHoverColor": ACCENT,
        "linkColor": ON_HEADER,
        "linkHoverColor": ACCENT,
        "logoWidth": "140",
        "searchPosition": "right",
        "searchStyle": "collapsed",
        "showSearch": True,
        "topRowHeight": 16,
    }


def build_layout_attrs() -> dict:
    return {
        "headerBgColor": HEADER,
        "isHeaderPinned": True,
        "isHeroUnderHeader": False,
        "isPageWidthFixed": False,
        "showHero": False,
    }


def footer_html() -> str:
    return (
        f"<div style='background:{HEADER};color:{ON_HEADER};"
        "font-family:IBM Plex Sans,Arial,sans-serif;padding:2.5rem 3rem 1.5rem;'>"
        f"<div style='font-weight:600;margin-bottom:8px;'>{BRAND_NAME}</div>"
        "<div style='font-size:13px;opacity:0.8;'>"
        "Partner Central — call off a sales agreement or request pricing.</div>"
        "<hr style='border:none;border-top:1px solid rgba(255,255,255,0.2);margin:1.25rem 0;'>"
        f"<div style='font-size:12px;opacity:0.6;'>© {BRAND_NAME}. Demo environment.</div>"
        "</div>"
    )


def run(cmd, cwd=None, check=True):
    print("+", " ".join(cmd))
    proc = subprocess.run(cmd, cwd=cwd, text=True)
    if check and proc.returncode != 0:
        raise SystemExit(proc.returncode)
    return proc


def load_json(path: Path):
    return json.loads(path.read_text())


def dump_json(path: Path, data):
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")


def walk(obj, fn):
    fn(obj)
    if isinstance(obj, dict):
        for v in obj.values():
            walk(v, fn)
    elif isinstance(obj, list):
        for v in obj:
            walk(v, fn)


def retrieve(org: str) -> None:
    if WORK.exists():
        shutil.rmtree(WORK)
    WORK.mkdir(parents=True)
    metadata = [f"ExperienceBundle:{BUNDLE_NAME}"]
    if BRANDING_MEMBER:
        metadata.append(f"NetworkBranding:{BRANDING_MEMBER}")
    cmd = [
        "sf", "project", "retrieve", "start",
        "--target-org", org,
        "--output-dir", str(WORK),
        "--wait", "10",
    ]
    for member in metadata:
        cmd.extend(["--metadata", member])
    run(cmd, cwd=ROOT)


def patch_branding(path: Path):
    data = load_json(path)
    values = data.setdefault("values", {})
    values.update({
        "ActionColor": ACCENT,
        "BorderColor": "#333333",
        "CardBackgroundColor": "rgba(8, 8, 8, 0.82)",
        "CompanyLogo": LOGO_URL,
        "DetailTextColor": "#C3C6CC",
        "HeaderFonts": "Montserrat",
        "LinkColor": ACCENT,
        "LoginBackgroundColor": HEADER,
        "LoginBackgroundImage": PRIMARY_URL,
        "OverlayTextColor": ON_HEADER,
        "PrimaryFont": "Lato",
        "TextColor": ON_HEADER,
        "TextTransformStyle": "none",
        "_ActionColorDarker": ACCENT_HOVER,
        "_ActionColorTrans": accent_rgba(0.9),
        "_HoverColor": accent_rgba(0.12),
        "_LinkColorDarker": ACCENT_HOVER,
        "_DxpPageBackgroundColor": HEADER,
        "_PrimaryAccentColor1": accent_rgb(ACCENT),
        "_PrimaryAccentColor2": accent_rgb(ACCENT_HOVER),
        "_PrimaryAccentColor3": accent_rgb(ACCENT_DEEP),
        "_PrimaryAccentForegroundColor1": "rgb(0, 0, 0)",
        "_PrimaryAccentForegroundColor2": "rgb(0, 0, 0)",
        "_PrimaryAccentForegroundColor3": "rgb(0, 0, 0)",
        "brandNavigationBackgroundColor": HEADER,
        "brandNavigationBarBackgroundColor": HEADER,
        "brandNavigationColorText": ON_HEADER,
        "_brandNavigationBarBackgroundColor": HEADER,
        "_brandNavigationItemBackgroundColorHover": accent_rgba(0.25),
        "_brandNavigationItemDividerColor": "rgba(255, 255, 255, 0.2)",
    })
    dump_json(path, data)


def patch_theme(path: Path, css: str, login_topbar_html: str = ""):
    data = load_json(path)
    data["customCSS"] = css

    def patch_node(node):
        if not isinstance(node, dict):
            return
        if node.get("componentName") == "runtime_sales_prm:prmThemeHeader":
            attrs = node.setdefault("componentAttributes", {})
            attrs.update(build_header_attrs())
        if node.get("componentName") == "forceCommunity:themeProfileMenu":
            attrs = node.setdefault("componentAttributes", {})
            attrs["buttonBackgroundColor"] = ACCENT
            attrs["buttonBackgroundHoverColor"] = ACCENT_HOVER
            attrs["buttonTextColor"] = HEADER
            attrs["buttonTextHoverColor"] = HEADER
            attrs["buttonBorderColor"] = ACCENT
            attrs["buttonBorderRadius"] = 0
        if node.get("componentName") == "siteforce:themeLayoutStarter":
            attrs = node.setdefault("componentAttributes", {})
            label = node.get("label")
            if label in ("Home", "Default"):
                attrs.update(build_layout_attrs())
        if node.get("componentName") == "forceCommunity:multiLevelNavigationWrapper":
            attrs = node.setdefault("componentAttributes", {})
            attrs["NavigationMenuEditorRefresh"] = "RLM_Default_Navigation"
        if node.get("componentName") == "forceCommunity:globalSearchInput":
            attrs = node.setdefault("componentAttributes", {})
            attrs["searchLabel"] = "Search"
            attrs["maxAutoCompleteResults"] = 5
        if node.get("componentName") == "forceCommunity:htmlBlock":
            attrs = node.setdefault("componentAttributes", {})
            rt = attrs.get("richTextValue") or ""
            if "Steps Corporation" in rt:
                attrs["richTextValue"] = footer_html()
            elif "Welcome Partners" in rt or "placeholderBanner" in rt:
                attrs["richTextValue"] = (
                    "<div></div>"
                )
        if (
            node.get("componentName") == "salesforceIdentity:loginBody2"
            and login_topbar_html
        ):
            for region in node.get("regions") or []:
                if region.get("regionName") != "header":
                    continue
                components = region.setdefault("components", [])
                already = any(
                    LOGIN_TOPBAR_MARKER
                    in ((c.get("componentAttributes") or {}).get("richTextValue") or "")
                    for c in components
                )
                if not already:
                    components.insert(0, _html_block(login_topbar_html))
                else:
                    for c in components:
                        rt = (c.get("componentAttributes") or {}).get("richTextValue") or ""
                        if LOGIN_TOPBAR_MARKER in rt:
                            c.setdefault("componentAttributes", {})["richTextValue"] = (
                                login_topbar_html
                            )
                break

    walk(data, patch_node)
    dump_json(path, data)


def patch_home(path: Path, hero: str, feature: str):
    """Replace the OOTB Partner Central home (Enablement programs / dashboard).

    The Enhanced template's home.json has no link-card HTML, so string-matching
    the QuantumBit home is a no-op. Rebuild the content region instead.
    ``feature`` is kept for call-site compatibility.
    """
    del feature
    data = load_json(path)
    section_id = str(uuid.uuid4())
    col_id = str(uuid.uuid4())
    html_id = str(uuid.uuid4())
    content_id = str(uuid.uuid4())
    hidden_id = str(uuid.uuid4())
    seo_id = str(uuid.uuid4())
    data["regions"] = [
        {
            "components": [{
                "componentAttributes": {
                    "background": "background: #000000",
                    "backgroundOverlay": "rgba(0,0,0,0)",
                    "contentAreaWidth": 100,
                    "sectionConfig": {
                        "UUID": section_id,
                        "columns": [{
                            "UUID": col_id,
                            "columnKey": "col1",
                            "columnName": "Home Column",
                            "columnWidth": "12",
                            "seedComponents": [{
                                "attributes": {
                                    "richTextValue": hero,
                                    "sfdc:identifier": "zebra_home_hero",
                                },
                                "fqn": "forceCommunity:htmlBlock",
                            }],
                        }],
                    },
                    "sectionHeight": 32,
                },
                "componentName": "forceCommunity:section",
                "id": section_id,
                "regions": [{
                    "components": [{
                        "componentAttributes": {"richTextValue": hero},
                        "componentName": "forceCommunity:htmlBlock",
                        "id": html_id,
                        "renderPriority": "NEUTRAL",
                        "renditionMap": {},
                        "type": "component",
                    }],
                    "id": col_id,
                    "regionLabel": "Home Column",
                    "regionName": "col1",
                    "renditionMap": {},
                    "type": "region",
                }],
                "renderPriority": "NEUTRAL",
                "renditionMap": {},
                "type": "component",
            }],
            "id": content_id,
            "regionName": "content",
            "type": "region",
        },
        {
            "components": [{
                "componentAttributes": {
                    "description": (
                        f"{BRAND_NAME} Partner Central — call off a sales agreement "
                        "or request a price concession."
                    ),
                    "title": f"{BRAND_NAME} Partner Central",
                },
                "componentName": "forceCommunity:seoAssistant",
                "id": seo_id,
                "renditionMap": {},
                "type": "component",
            }],
            "id": hidden_id,
            "regionName": "sfdcHiddenRegion",
            "type": "region",
        },
    ]
    dump_json(path, data)


LOGIN_BRAND_MARKER = "brand-login-brand"
LOGIN_TOPBAR_MARKER = "brand-login-topbar"


def _sanitize_html_block(html: str) -> str:
    """htmlBlock allows a short tag list — never style/script/link."""
    html = re.sub(r"<style\b[^>]*>.*?</style>", "", html, flags=re.I | re.S)
    html = re.sub(r"<script\b[^>]*>.*?</script>", "", html, flags=re.I | re.S)
    html = re.sub(r"</?link\b[^>]*>", "", html, flags=re.I)
    return html.strip()


def _html_block(html: str, component_id: str | None = None):
    return {
        "componentAttributes": {"richTextValue": _sanitize_html_block(html)},
        "componentName": "forceCommunity:htmlBlock",
        "id": component_id or str(uuid.uuid4()),
        "renderPriority": "NEUTRAL",
        "renditionMap": {},
        "type": "component",
    }


def patch_login(path: Path, brand_html: str, head_html: str = ""):
    data = load_json(path)

    def patch_node(node):
        if not isinstance(node, dict):
            return
        if node.get("componentName") == "forceCommunity:seoAssistant":
            attrs = node.setdefault("componentAttributes", {})
            attrs["title"] = f"{BRAND_NAME} Partner Central"
            # Head tags: inline script/style and relative src all fail
            # ExperienceBundle validation. Login card is restyled in theme CSS.
            attrs.pop("customHeadTags", None)
        if node.get("componentName") == "salesforceIdentity:loginForm2":
            attrs = node.setdefault("componentAttributes", {})
            attrs["loginButtonLabel"] = "Log in"

    walk(data, patch_node)

    for region in data.get("regions") or []:
        if region.get("regionName") != "content":
            continue
        components = region.setdefault("components", [])
        components[:] = [
            c for c in components
            if c.get("componentName") != "salesforceIdentity:communityLogo2"
        ]
        already = any(
            LOGIN_BRAND_MARKER in ((c.get("componentAttributes") or {}).get("richTextValue") or "")
            for c in components
        )
        if not already:
            components.insert(0, _html_block(brand_html))
        else:
            for c in components:
                rt = (c.get("componentAttributes") or {}).get("richTextValue") or ""
                if LOGIN_BRAND_MARKER in rt:
                    c.setdefault("componentAttributes", {})["richTextValue"] = (
                        _sanitize_html_block(brand_html)
                    )
        break

    dump_json(path, data)


def patch_quote_detail(exp: Path):
    """Replace generic Quote Detail with Configure & Quote (partner cart + summary)."""
    views = exp / "views"
    if not views.exists():
        return
    patched = 0
    for path in views.glob("*.json"):
        data = load_json(path)
        view_type = data.get("viewType") or ""
        name = path.name.lower()
        if not (
            str(view_type).startswith("detail-0Q0")
            or "quotedetail" in name
            or name in ("quote.json", "quotes.json")
        ):
            continue
        if data.get("viewType") == "quote-list" or str(view_type).startswith("list-"):
            continue
        for region in data.get("regions") or []:
            if region.get("regionName") != "content":
                continue
            region["components"] = [
                _community_component(
                    "c:rlmPartnerQuote",
                    {"recordId": "{!recordId}"},
                )
            ]
            patched += 1
        dump_json(path, data)
        print(f"  patched quote detail {path.name}")
    home = load_json(exp / "views/home.json")
    app_page_id = home.get("appPageId")
    if not app_page_id:
        print("  skip quote pages: no appPageId on home")
        return
    if not patched:
        _write_object_detail_pages(
            exp,
            app_page_id,
            key_prefix="0Q0",
            url_prefix="quote",
            route_stem="quote",
            label="Quote",
            view_dev_name="Quote",
        )
        print("  created quote detail Configure & Quote")
    _ensure_quote_list_page(exp, app_page_id)


def _ensure_quote_list_page(exp: Path, app_page_id: str):
    """Object pages for Quote require list-0Q0 in addition to detail/related."""
    list_view = exp / "views/quoteList.json"
    if list_view.exists():
        return
    view_id = str(uuid.uuid4())
    dump_json(exp / "routes/quoteList.json", {
        "activeViewId": view_id,
        "appPageId": app_page_id,
        "configurationTags": [],
        "devName": "Quote_List",
        "id": str(uuid.uuid4()),
        "label": "Quotes",
        "routeType": "list-0Q0",
        "type": "route",
        "urlPrefix": "quote",
    })
    dump_json(list_view, {
        "appPageId": app_page_id,
        "componentName": "siteforce:sldsOneColLayout",
        "dataProviders": [],
        "id": view_id,
        "label": "Quotes",
        "regions": [
            {"id": str(uuid.uuid4()), "regionName": "header", "type": "region"},
            {
                "components": [{
                    "componentAttributes": {
                        "enableInlineEdit": True,
                        "filterName": "Recent",
                        "layout": "FULL",
                        "pageSize": 25,
                        "scope": "Quote",
                        "showActionBar": True,
                        "showChartsPanel": False,
                        "showDisplay": "showall",
                        "showFilterPanel": True,
                        "showImageIcon": True,
                        "showManualRefreshButton": True,
                        "showObjectName": True,
                        "showPinnedList": True,
                        "showSearchBar": True,
                    },
                    "componentName": "forceCommunity:objectHome",
                    "id": str(uuid.uuid4()),
                    "renderPriority": "NEUTRAL",
                    "renditionMap": {},
                    "type": "component",
                }],
                "id": str(uuid.uuid4()),
                "regionName": "content",
                "type": "region",
            },
            {"id": str(uuid.uuid4()), "regionName": "footer", "type": "region"},
        ],
        "themeLayoutType": "Inner",
        "type": "view",
        "viewType": "list-0Q0",
    })
    print("  created quote list-0Q0")


def _has_component(node, name):
    if isinstance(node, dict):
        if node.get("componentName") == name:
            return True
        return any(_has_component(value, name) for value in node.values())
    if isinstance(node, list):
        return any(_has_component(item, name) for item in node)
    return False


def _inject_start_quote(node):
    """Place the start-quote banner above objectHome, including nested sections."""
    changed = False
    if isinstance(node, dict):
        comps = node.get("components")
        if isinstance(comps, list):
            already = any(
                isinstance(c, dict) and c.get("componentName") == "c:rlmPartnerStartQuote"
                for c in comps
            )
            has_home = any(
                isinstance(c, dict) and c.get("componentName") == "forceCommunity:objectHome"
                for c in comps
            )
            if has_home and not already:
                node["components"] = [
                    _community_component(
                        "c:rlmPartnerStartQuote",
                        {"autoStart": False},
                    ),
                    *comps,
                ]
                changed = True
        for value in node.values():
            if _inject_start_quote(value):
                changed = True
    elif isinstance(node, list):
        for item in node:
            if _inject_start_quote(item):
                changed = True
    return changed


def patch_quote_list(exp: Path):
    """Put Start Configure & Quote on quote list pages (New is not available to partners)."""
    views = exp / "views"
    for name in ("viewQuotes.json", "quoteList.json"):
        path = views / name
        if not path.exists():
            continue
        data = load_json(path)
        if _has_component(data, "c:rlmPartnerStartQuote"):
            continue
        if _inject_start_quote(data):
            dump_json(path, data)
            print(f"  patched quote list {name}")
            continue
        for region in data.get("regions") or []:
            if region.get("regionName") != "content":
                continue
            comps = region.get("components") or []
            region["components"] = [
                _community_component(
                    "c:rlmPartnerStartQuote",
                    {"autoStart": False},
                ),
                *comps,
            ]
            dump_json(path, data)
            print(f"  patched quote list {name} (content region)")
            break


def patch_my_account(path: Path):
    """Replace Account Information tabs with the partner pulse dashboard."""
    if not path.exists():
        return
    data = load_json(path)
    data["label"] = "My Account"

    def swap(node):
        if not isinstance(node, dict):
            return
        if node.get("componentName") == "forceCommunity:recordHeadline":
            node["componentName"] = "c:rlmPartnerPulse"
            node["componentAttributes"] = {}
        if node.get("fqn") == "forceCommunity:recordHeadline":
            node["fqn"] = "c:rlmPartnerPulse"
            node["attributes"] = {}

    walk(data, swap)

    def strip_tabs(node):
        if not isinstance(node, dict):
            return
        comps = node.get("components")
        if isinstance(comps, list):
            node["components"] = [
                c for c in comps
                if not (
                    isinstance(c, dict)
                    and c.get("componentName") == "forceCommunity:recordHomeTabs"
                )
            ]
        seeds = node.get("seedComponents")
        if isinstance(seeds, list):
            node["seedComponents"] = [
                s for s in seeds
                if not (isinstance(s, dict) and s.get("fqn") == "forceCommunity:recordHomeTabs")
            ]

    walk(data, strip_tabs)
    dump_json(path, data)


def patch_main_app(path: Path):
    data = load_json(path)
    data["headMarkup"] = None
    dump_json(path, data)


def patch_network_branding(path: Path) -> None:
    text = path.read_text()
    swaps = {
        "primaryColor": ACCENT,
        "loginPrimaryColor": ACCENT,
        "secondaryColor": HEADER,
        "tertiaryColor": HEADER,
        "zeronaryColor": HEADER,
        "quaternaryColor": MUTED,
    }
    for tag, color in swaps.items():
        text = re.sub(
            rf"<{tag}>#[0-9A-Fa-f]{{3,8}}</{tag}>",
            f"<{tag}>{color}</{tag}>",
            text,
        )
    path.write_text(text)


def _hidden_region():
    return {
        "components": [{
            "componentAttributes": {
                "description": "",
                "title": "{!Record._Object}: {!Record._Title}",
            },
            "componentName": "forceCommunity:seoAssistant",
            "id": str(uuid.uuid4()),
            "renditionMap": {},
            "type": "component",
        }],
        "id": str(uuid.uuid4()),
        "regionName": "sfdcHiddenRegion",
        "type": "region",
    }



def _object_home_attrs(scope: str, filter_name: str) -> dict:
    return {
        "enableInlineEdit": False,
        "filterName": filter_name,
        "layout": "FULL",
        "pageSize": 25,
        "scope": scope,
        "showActionBar": True,
        "showChartsPanel": False,
        "showDisplay": "showall",
        "showFilterPanel": True,
        "showImageIcon": False,
        "showManualRefreshButton": True,
        "showObjectName": False,
        "showPinnedList": True,
        "showSearchBar": True,
    }


def _list_section(heading_html: str, scope: str, filter_name: str, identifier: str, column_label: str):
    section_id = str(uuid.uuid4())
    col_id = str(uuid.uuid4())
    return {
        "componentAttributes": {
            "background": "background: #f4f4f4",
            "backgroundOverlay": "rgba(0,0,0,0)",
            "contentAreaWidth": 100,
            "sectionConfig": {
                "UUID": section_id,
                "columns": [{
                    "UUID": col_id,
                    "columnKey": "col1",
                    "columnName": column_label,
                    "columnWidth": "12",
                    "seedComponents": [
                        {
                            "attributes": {"richTextValue": heading_html},
                            "fqn": "forceCommunity:htmlBlock",
                        },
                        {
                            "attributes": {
                                "filterName": filter_name,
                                "scope": scope,
                                "sfdc:identifier": identifier,
                            },
                            "fqn": "forceCommunity:objectHome",
                        },
                    ],
                }],
            },
            "sectionHeight": 32,
        },
        "componentName": "forceCommunity:section",
        "id": section_id,
        "regions": [{
            "components": [
                _html_block(heading_html),
                {
                    "componentAttributes": _object_home_attrs(scope, filter_name),
                    "componentName": "forceCommunity:objectHome",
                    "id": str(uuid.uuid4()),
                    "renderPriority": "NEUTRAL",
                    "renditionMap": {},
                    "type": "component",
                },
            ],
            "id": col_id,
            "regionLabel": column_label,
            "regionName": "col1",
            "renditionMap": {},
            "type": "region",
        }],
        "renderPriority": "NEUTRAL",
        "renditionMap": {},
        "type": "component",
    }


def _lwc_section(heading_html: str, component_name: str, column_label: str):
    section_id = str(uuid.uuid4())
    col_id = str(uuid.uuid4())
    lwc_component = {
        "componentAttributes": {},
        "componentName": component_name,
        "id": str(uuid.uuid4()),
        "renderPriority": "NEUTRAL",
        "renditionMap": {},
        "type": "component",
    }
    seed = [{
        "attributes": {},
        "fqn": component_name,
    }]
    components = [lwc_component]
    if heading_html:
        seed.insert(0, {
            "attributes": {"richTextValue": heading_html},
            "fqn": "forceCommunity:htmlBlock",
        })
        components.insert(0, _html_block(heading_html))
    return {
        "componentAttributes": {
            "background": "background: #f4f4f4",
            "backgroundOverlay": "rgba(0,0,0,0)",
            "contentAreaWidth": 100,
            "sectionConfig": {
                "UUID": section_id,
                "columns": [{
                    "UUID": col_id,
                    "columnKey": "col1",
                    "columnName": column_label,
                    "columnWidth": "12",
                    "seedComponents": seed,
                }],
            },
            "sectionHeight": 32,
        },
        "componentName": "forceCommunity:section",
        "id": section_id,
        "regions": [{
            "components": components,
            "id": col_id,
            "regionLabel": column_label,
            "regionName": "col1",
            "renditionMap": {},
            "type": "region",
        }],
        "renderPriority": "NEUTRAL",
        "renditionMap": {},
        "type": "component",
    }


def _community_component(name, attrs=None):
    return {
        "componentAttributes": attrs or {},
        "componentName": name,
        "id": str(uuid.uuid4()),
        "renderPriority": "NEUTRAL",
        "renditionMap": {},
        "type": "component",
    }


def _quote_detail_view(app_page_id, view_id, label):
    """Partner Quote Detail: Configure & Quote cart + summary rail."""
    return {
        "appPageId": app_page_id,
        "componentName": "siteforce:sldsOneColLayout",
        "dataProviders": [],
        "id": view_id,
        "label": label,
        "regions": [
            {"id": str(uuid.uuid4()), "regionName": "header", "type": "region"},
            {
                "components": [
                    _community_component(
                        "c:rlmPartnerQuote",
                        {"recordId": "{!recordId}"},
                    ),
                ],
                "id": str(uuid.uuid4()),
                "regionName": "content",
                "type": "region",
            },
            {"id": str(uuid.uuid4()), "regionName": "footer", "type": "region"},
            _hidden_region(),
        ],
        "themeLayoutType": "Inner",
        "type": "view",
        "viewType": "detail-0Q0",
    }


def _sales_agreement_detail_view(app_page_id, view_id, label):
    """Partner record page: branded summary LWC (metrics + contracted prices).

    Manufacturing Cloud's agreementTermsContainer does not render in Partner
    Central Enhanced, and pinning Quick Quote in the Experience header region
    overlays the site chrome. Keep the native chrome off this page.
    """
    return {
        "appPageId": app_page_id,
        "componentName": "siteforce:sldsOneColLayout",
        "dataProviders": [],
        "id": view_id,
        "label": label,
        "regions": [
            {"id": str(uuid.uuid4()), "regionName": "header", "type": "region"},
            {
                "components": [
                    _community_component(
                        "c:rlmPartnerAgreement",
                        {"recordId": "{!recordId}"},
                    ),
                ],
                "id": str(uuid.uuid4()),
                "regionName": "content",
                "type": "region",
            },
            {"id": str(uuid.uuid4()), "regionName": "footer", "type": "region"},
            _hidden_region(),
        ],
        "themeLayoutType": "Inner",
        "type": "view",
        "viewType": "detail-0YA",
    }


def _write_object_detail_pages(
    exp: Path,
    app_page_id: str,
    *,
    key_prefix: str,
    url_prefix: str,
    route_stem: str,
    label: str,
    view_dev_name: str,
):
    detail_view_id = str(uuid.uuid4())
    related_view_id = str(uuid.uuid4())
    dump_json(exp / f"routes/{route_stem}.json", {
        "activeViewId": detail_view_id,
        "appPageId": app_page_id,
        "configurationTags": [],
        "devName": f"{view_dev_name}_Detail",
        "id": str(uuid.uuid4()),
        "label": label,
        "routeType": f"detail-{key_prefix}",
        "type": "route",
        "urlPrefix": url_prefix,
    })
    if key_prefix == "0YA":
        dump_json(
            exp / f"views/{route_stem}.json",
            _sales_agreement_detail_view(app_page_id, detail_view_id, label),
        )
    elif key_prefix == "0Q0":
        dump_json(
            exp / f"views/{route_stem}.json",
            _quote_detail_view(app_page_id, detail_view_id, label),
        )
    else:
        dump_json(exp / f"views/{route_stem}.json", {
            "appPageId": app_page_id,
            "componentName": "siteforce:sldsOneColLayout",
            "dataProviders": [],
            "id": detail_view_id,
            "label": label,
            "regions": [
                {"id": str(uuid.uuid4()), "regionName": "header", "type": "region"},
                {
                    "components": [
                        {
                            "componentAttributes": {"recordId": "{!recordId}"},
                            "componentName": "forceCommunity:recordHeadline",
                            "id": str(uuid.uuid4()),
                            "renderPriority": "NEUTRAL",
                            "renditionMap": {},
                            "type": "component",
                        },
                        {
                            "componentAttributes": {
                                "detailsTabLabel": "Details",
                                "discussionsTabLabel": "Feed",
                                "recordId": "{!recordId}",
                                "relatedTabLabel": "Related",
                                "showLegacyActivityComposer": False,
                                "tab1Type": "details",
                                "tab2Type": "related",
                                "tab3Type": "none",
                                "tab4Type": "none",
                                "timelineTabLabel": "Activity",
                            },
                            "componentName": "forceCommunity:recordHomeTabs",
                            "id": str(uuid.uuid4()),
                            "renderPriority": "NEUTRAL",
                            "renditionMap": {},
                            "type": "component",
                        },
                    ],
                    "id": str(uuid.uuid4()),
                    "regionName": "content",
                    "type": "region",
                },
                {"id": str(uuid.uuid4()), "regionName": "footer", "type": "region"},
                _hidden_region(),
            ],
            "themeLayoutType": "Inner",
            "type": "view",
            "viewType": f"detail-{key_prefix}",
        })
    dump_json(exp / f"routes/{route_stem}RelatedList.json", {
        "activeViewId": related_view_id,
        "appPageId": app_page_id,
        "configurationTags": [],
        "devName": f"{view_dev_name}_Related_List",
        "id": str(uuid.uuid4()),
        "label": f"{label} Related List",
        "routeType": f"relatedlist-{key_prefix}",
        "type": "route",
        "urlPrefix": url_prefix,
    })
    dump_json(exp / f"views/{route_stem}RelatedList.json", {
        "appPageId": app_page_id,
        "componentName": "siteforce:sldsOneColLayout",
        "dataProviders": [],
        "id": related_view_id,
        "label": f"{label} Related List",
        "regions": [
            {"id": str(uuid.uuid4()), "regionName": "header", "type": "region"},
            {
                "components": [{
                    "componentAttributes": {
                        "customTitle": "",
                        "parentRecordId": "{!recordId}",
                        "relatedListName": "{!relationshipApiName}",
                        "showBreadCrumbs": True,
                        "showCustomTitle": False,
                        "showManualRefreshButton": True,
                        "showRowNumbers": True,
                    },
                    "componentName": "forceCommunity:relatedList",
                    "id": str(uuid.uuid4()),
                    "renderPriority": "NEUTRAL",
                    "renditionMap": {},
                    "type": "component",
                }],
                "id": str(uuid.uuid4()),
                "regionName": "content",
                "type": "region",
            },
            {"id": str(uuid.uuid4()), "regionName": "footer", "type": "region"},
        ],
        "themeLayoutType": "Inner",
        "type": "view",
        "viewType": f"relatedlist-{key_prefix}",
    })


def ensure_sales_agreement_pages(exp: Path, sa_heading: str, prices_heading: str):
    """Sales Agreement object list at /my-agreements (LWC catalog, not a custom page).

    Partner Central Enhanced 404s custom-* routes (home CTAs to /my-agreements
    showed "URL No Longer Exists"). list-0YA is a real object-home route; the
    live URL is /my-agreements/SalesAgreement/Default.

    Never regenerate these once the live bundle already has them — new UUIDs
    collide with the org's My Agreements pageAccess / labels.
    """
    if (
        (exp / "views/viewSalesAgreements.json").exists()
        or (exp / "views/myAgreements.json").exists()
        or (exp / "views/salesAgreement.json").exists()
    ):
        print("  keeping existing sales agreement pages")
        return
    home = load_json(exp / "views/home.json")
    app_page_id = home.get("appPageId")
    if not app_page_id:
        print("  skip SA pages: no appPageId on home")
        return
    for stale in (
        "routes/salesAgreementDetail.json",
        "views/salesAgreementDetail.json",
        # Partner Central Enhanced cannot host SalesAgreementProduct object pages.
        "routes/viewSalesAgreementProducts.json",
        "views/viewSalesAgreementProducts.json",
        "routes/salesAgreementProduct.json",
        "views/salesAgreementProduct.json",
        "routes/salesAgreementProductRelatedList.json",
        "views/salesAgreementProductRelatedList.json",
        "routes/contractedPrice.json",
        "views/contractedPrice.json",
        "routes/contractedPriceRelatedList.json",
        "views/contractedPriceRelatedList.json",
    ):
        path = exp / stale
        if path.exists():
            path.unlink()

    list_view_id = str(uuid.uuid4())
    dump_json(exp / "routes/viewSalesAgreements.json", {
        "activeViewId": list_view_id,
        "appPageId": app_page_id,
        "configurationTags": [],
        "devName": "View_Sales_Agreements",
        "id": str(uuid.uuid4()),
        "label": "My Agreements",
        "routeType": "list-0YA",
        "type": "route",
        "urlPrefix": "my-agreements",
    })
    dump_json(exp / "views/viewSalesAgreements.json", {
        "appPageId": app_page_id,
        "componentName": "siteforce:dynamicLayout",
        "dataProviders": [],
        "id": list_view_id,
        "label": "My Agreements",
        "regions": [{
            "components": [
                _lwc_section(
                    "",
                    "c:rlmPartnerContractedPrices",
                    "Agreements Column",
                ),
            ],
            "id": str(uuid.uuid4()),
            "regionName": "content",
            "type": "region",
        }],
        "themeLayoutType": "Inner",
        "type": "view",
        "viewType": "list-0YA",
    })
    _write_object_detail_pages(
        exp,
        app_page_id,
        key_prefix="0YA",
        url_prefix="salesagreement",
        route_stem="salesAgreement",
        label="Sales Agreement",
        view_dev_name="Sales_Agreement",
    )
    print("  injected Sales Agreement list + branded record summary")


def strip_empty_custom_head_tags(exp: Path):
    """Empty customHeadTags fail ExperienceBundle deploy on API 67."""
    def clean(node):
        if isinstance(node, dict):
            if node.get("componentName") == "forceCommunity:seoAssistant":
                attrs = node.get("componentAttributes") or {}
                if not attrs.get("customHeadTags"):
                    attrs.pop("customHeadTags", None)
            for value in node.values():
                clean(value)
        elif isinstance(node, list):
            for value in node:
                clean(value)

    for path in (exp / "views").glob("*.json"):
        data = load_json(path)
        clean(data)
        dump_json(path, data)


def _json_in(folder: Path, preferred: str) -> Path:
    direct = folder / preferred
    if direct.exists():
        return direct
    matches = sorted(folder.glob("*.json"))
    if len(matches) == 1:
        return matches[0]
    names = ", ".join(path.name for path in matches) or "none"
    raise SystemExit(
        f"Expected {preferred} or a single JSON file in {folder}. Found: {names}"
    )


def apply_patches():
    exp = WORK / "experiences" / BUNDLE_NAME
    css = render_brand_file("theme.css")
    hero = render_brand_file("home-hero.html").strip()
    feature = render_brand_file("home-feature.html").strip()
    login_brand = render_brand_file("login-brand.html").strip()
    login_topbar = render_brand_file("login-topbar.html").strip()
    login_head = render_brand_file("login-head.html").strip()
    sa_heading = render_brand_file("agreements-heading.html").strip()
    prices_heading = render_brand_file("prices-heading.html").strip()
    patch_branding(_json_in(exp / "brandingSets", "partnerCentralEnhanced.json"))
    patch_theme(_json_in(exp / "themes", "partnerCentralEnhanced.json"), css, login_topbar)
    patch_home(exp / "views/home.json", hero, feature)
    ensure_sales_agreement_pages(exp, sa_heading, prices_heading)
    patch_my_account(exp / "views/accountInformation.json")
    patch_quote_detail(exp)
    patch_quote_list(exp)
    # Script src only — inline script bodies are rejected (and `<` in JS
    # is parsed as a tag). The JS file paints .cCenterPanel and loads
    # RLM_PartnerLogin.css.
    patch_login(exp / "views/login.json", login_brand, login_head)
    patch_main_app(exp / "config/mainAppPage.json")
    login_app = exp / "config/loginAppPage.json"
    if login_app.exists():
        data = load_json(login_app)
        # <style> in headMarkup is stripped at publish. A same-origin
        # stylesheet <link> is allowed in customHeadTags; keep headMarkup
        # empty so Picasso does not drop the whole login head.
        data.pop("headMarkup", None)
        dump_json(login_app, data)
    nb = WORK / "networkBranding" / f"{BRANDING_MEMBER}.networkBranding-meta.xml"
    if nb.exists():
        patch_network_branding(nb)
    strip_empty_custom_head_tags(exp)


def _content_asset(name: str, source: Path, network: str) -> tuple[str, bytes]:
    suffix = source.suffix.lower() or ".png"
    meta = f"""<?xml version="1.0" encoding="UTF-8"?>
<ContentAsset xmlns="http://soap.sforce.com/2006/04/metadata">
    <isVisibleByExternalUsers>true</isVisibleByExternalUsers>
    <language>en_US</language>
    <masterLabel>{name}</masterLabel>
    <originNetwork>{network}</originNetwork>
    <relationships>
        <network>
            <access>VIEWER</access>
            <name>{network}</name>
        </network>
        <workspace>
            <access>INFERRED</access>
            <isManagingWorkspace>true</isManagingWorkspace>
            <name>sfdc_asset_company_assets</name>
        </workspace>
    </relationships>
    <versions>
        <version>
            <number>1</number>
            <pathOnClient>{name}{suffix}</pathOnClient>
        </version>
    </versions>
</ContentAsset>
"""
    return meta, source.read_bytes()


def deploy(org: str, logo: Path, primary: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="partner-brand-") as stage:
        stage_path = Path(stage)
        (stage_path / "sfdx-project.json").write_text(json.dumps({
            "packageDirectories": [{"path": "force-app", "default": True}],
            "name": "partner-portal-brand",
            "namespace": "",
            "sourceApiVersion": "67.0",
        }))
        dest = stage_path / "force-app/main/default"
        if FORCE.exists():
            shutil.copytree(FORCE, dest)
        exp_src = WORK / "experiences" / BUNDLE_NAME
        if not exp_src.exists():
            raise SystemExit(f"Retrieved bundle not found at {exp_src}")
        exp_dest = dest / "experiences" / BUNDLE_NAME
        if exp_dest.exists():
            shutil.rmtree(exp_dest)
        shutil.copytree(exp_src, exp_dest)
        site_meta = WORK / "experiences" / f"{BUNDLE_NAME}.site-meta.xml"
        if site_meta.exists():
            shutil.copy2(site_meta, dest / "experiences" / site_meta.name)
        branding_src = WORK / "networkBranding"
        if branding_src.exists():
            branding_dest = dest / "networkBranding"
            if branding_dest.exists():
                shutil.rmtree(branding_dest)
            shutil.copytree(branding_src, branding_dest)
        # Never deploy Network metadata. A retrieved UnderConstruction network
        # takes a live Experience site down.
        for network_file in dest.rglob("*.network-meta.xml"):
            network_file.unlink()
        assets = dest / "contentassets"
        assets.mkdir(parents=True, exist_ok=True)
        for asset_name, image in ((LOGO_ASSET, logo), (PRIMARY_ASSET, primary)):
            meta, binary = _content_asset(asset_name, image, NETWORK_NAME)
            (assets / f"{asset_name}.asset-meta.xml").write_text(meta)
            (assets / f"{asset_name}.asset").write_bytes(binary)
        sr = dest / "staticresources"
        sr.mkdir(parents=True, exist_ok=True)
        (sr / "RLM_PartnerLogin.css").write_text(render_brand_file("login.css"))
        (sr / "RLM_PartnerLoginJs.js").write_text(render_brand_file("login.js"))
        run([
            "sf", "project", "deploy", "start",
            "--source-dir", "force-app",
            "--target-org", org,
            "--wait", "35",
        ], cwd=stage_path)


def publish(org: str) -> None:
    run([
        "sf", "community", "publish",
        "--name", NETWORK_NAME,
        "--target-org", org,
    ])


def _sf_json(cmd: list[str]) -> dict:
    proc = subprocess.run(cmd, text=True, capture_output=True)
    if proc.returncode != 0:
        raise SystemExit(proc.stderr.strip() or proc.stdout.strip() or "sf command failed")
    return json.loads(proc.stdout)


def _metadata_names(org: str, metadata_type: str) -> list[str]:
    data = _sf_json([
        "sf", "org", "list", "metadata",
        "--metadata-type", metadata_type,
        "--target-org", org,
        "--json",
    ])
    result = data.get("result") or []
    if isinstance(result, dict):
        result = result.get("records") or result.get("metadataObjects") or []
    names = []
    for item in result:
        if isinstance(item, dict) and item.get("fullName"):
            names.append(item["fullName"])
    return names


def discover(org: str, bundle: str | None, network: str | None, branding: str | None) -> None:
    global BUNDLE_NAME, NETWORK_NAME, BRANDING_MEMBER
    bundles = _metadata_names(org, "ExperienceBundle")
    networks = _metadata_names(org, "Network")
    brandings = _metadata_names(org, "NetworkBranding")
    if bundle:
        BUNDLE_NAME = bundle
    elif len(bundles) == 1:
        BUNDLE_NAME = bundles[0]
    else:
        raise SystemExit(
            "Pass --experience-bundle. Found: " + ", ".join(bundles or ["none"])
        )
    if network:
        NETWORK_NAME = network
    elif len(networks) == 1:
        NETWORK_NAME = networks[0]
    else:
        raise SystemExit(
            "Pass --network. Found: " + ", ".join(networks or ["none"])
        )
    if branding:
        BRANDING_MEMBER = branding
    elif brandings:
        preferred = "cb" + NETWORK_NAME
        BRANDING_MEMBER = preferred if preferred in brandings else brandings[0]
    else:
        BRANDING_MEMBER = ""


def _lum(color: tuple[int, int, int]) -> float:
    r, g, b = color
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def _sat(color: tuple[int, int, int]) -> float:
    r, g, b = [c / 255 for c in color]
    hi, lo = max(r, g, b), min(r, g, b)
    if hi == 0:
        return 0.0
    return (hi - lo) / hi


def _prominent(path: Path) -> list[tuple[tuple[int, int, int], int]]:
    from PIL import Image
    image = Image.open(path).convert("RGB")
    image.thumbnail((96, 96))
    buckets: dict[tuple[int, int, int], int] = {}
    for r, g, b in image.getdata():
        key = (r // 16 * 16, g // 16 * 16, b // 16 * 16)
        buckets[key] = buckets.get(key, 0) + 1
    ranked = sorted(buckets.items(), key=lambda item: item[1], reverse=True)
    return [(color, count) for color, count in ranked if count >= 4] or ranked[:1]


def _darken(color: tuple[int, int, int], factor: float = 0.85) -> str:
    return "#{:02X}{:02X}{:02X}".format(*(max(0, int(c * factor)) for c in color))


def _hex(color: tuple[int, int, int]) -> str:
    return "#{:02X}{:02X}{:02X}".format(*color)


def sample_palette(primary: Path, logo: Path | None) -> dict[str, str]:
    ranked = _prominent(primary)
    total = sum(count for _, count in ranked) or 1
    avg_lum = sum(_lum(color) * count for color, count in ranked) / total
    avg_sat = sum(_sat(color) * count for color, count in ranked) / total
    accent = max((color for color, _ in ranked), key=_sat)
    if avg_lum < 80 and avg_sat < 0.25 and logo is not None:
        header = (255, 255, 255)
        on_header = (17, 17, 17)
        logo_colors = [color for color, _ in _prominent(logo)]
        logo_accent = max(logo_colors, key=_sat)
        if _sat(logo_accent) > _sat(accent):
            accent = logo_accent
    else:
        darkest = min((color for color, _ in ranked), key=_lum)
        header = darkest if _lum(darkest) < 90 else (11, 31, 51)
        on_header = (255, 255, 255) if _lum(header) < 150 else (17, 17, 17)
    if _sat(accent) < 0.18:
        accent = (1, 118, 211)
    return {
        "accent": _hex(accent),
        "accent_hover": _darken(accent),
        "accent_deep": _darken(accent, 0.7),
        "header": _hex(header),
        "on_header": _hex(on_header),
    }


def apply_palette(palette: dict[str, str]) -> None:
    global ACCENT, ACCENT_HOVER, ACCENT_DEEP, HEADER, ON_HEADER, LOGO_URL, PRIMARY_URL, BRAND_NAME
    ACCENT = palette["accent"]
    ACCENT_HOVER = palette["accent_hover"]
    ACCENT_DEEP = palette["accent_deep"]
    HEADER = palette["header"]
    ON_HEADER = palette["on_header"]


def main() -> None:
    global BRAND_NAME, LOGO_URL, PRIMARY_URL
    parser = argparse.ArgumentParser(description="Brand Partner Central from a logo and primary image.")
    parser.add_argument("--target-org", required=True)
    parser.add_argument("--logo", required=True, type=Path)
    parser.add_argument("--primary-image", required=True, type=Path)
    parser.add_argument("--brand-name", required=True)
    parser.add_argument("--accent", help="Override the sampled accent hex, for example #A8F932")
    parser.add_argument("--header", help="Override the sampled header hex")
    parser.add_argument("--experience-bundle", help="ExperienceBundle fullName. Discovered when only one exists.")
    parser.add_argument("--network", help="Network fullName. Discovered when only one exists.")
    parser.add_argument("--network-branding", help="NetworkBranding fullName.")
    parser.add_argument("--skip-retrieve", action="store_true")
    parser.add_argument("--skip-deploy", action="store_true")
    parser.add_argument("--skip-publish", action="store_true")
    parser.add_argument("--sample-only", action="store_true", help="Print the sampled palette and exit.")
    args = parser.parse_args()
    if not args.logo.exists():
        raise SystemExit(f"Logo not found: {args.logo}")
    if not args.primary_image.exists():
        raise SystemExit(f"Primary image not found: {args.primary_image}")
    BRAND_NAME = args.brand_name.strip()
    palette = sample_palette(args.primary_image, args.logo)
    if args.accent:
        palette["accent"] = args.accent
        palette["accent_hover"] = _darken(_hex_to_rgb(args.accent))
        palette["accent_deep"] = _darken(_hex_to_rgb(args.accent), 0.7)
    if args.header:
        palette["header"] = args.header
    apply_palette(palette)
    LOGO_URL = f"/file-asset/{LOGO_ASSET}?v=1"
    PRIMARY_URL = f"/file-asset/{PRIMARY_ASSET}?v=1"
    print("Palette:", json.dumps(palette))
    if args.sample_only:
        return
    discover(args.target_org, args.experience_bundle, args.network, args.network_branding)
    if not args.skip_retrieve:
        retrieve(args.target_org)
    elif not (WORK / "experiences" / BUNDLE_NAME).exists():
        raise SystemExit(f"No retrieved bundle at {WORK}; omit --skip-retrieve")
    apply_patches()
    if not args.skip_deploy:
        deploy(args.target_org, args.logo, args.primary_image)
    if not args.skip_publish:
        publish(args.target_org)
    print(f"Partner Central branded for {BRAND_NAME}.")
    print("Call-off stays on the Sales Agreement page. Configure & Quote stays on the quote page.")


if __name__ == "__main__":
    main()
