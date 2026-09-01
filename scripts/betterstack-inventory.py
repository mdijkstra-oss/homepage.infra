#!/usr/bin/env python3
"""Every Better Stack resource in the account, marked against tofu's state.

`tofu state list` can only show what this configuration owns; a resource created
by hand in their UI is invisible to it and to `plan`. This asks Better Stack what
exists and marks each against state, which is the only way to see drift in the
direction of "someone added something".

Status page sections and resources are listed per page rather than globally,
because that is the only way their API exposes them — and a duplicate section is
exactly the kind of thing that is otherwise invisible here.
"""

import json
import os
import subprocess
import sys
import urllib.error
import urllib.request

UPTIME = "https://uptime.betterstack.com/api/v2"
TELEMETRY = "https://telemetry.betterstack.com/api/v1"

# endpoint, label, (name attribute, secondary attribute)
ENDPOINTS = (
    (UPTIME, "monitors", "monitor", ("pronounceable_name", "url")),
    (UPTIME, "monitor-groups", "group", ("name", None)),
    (UPTIME, "heartbeats", "heartbeat", ("name", None)),
    (UPTIME, "status-pages", "status page", ("company_name", "subdomain")),
    (UPTIME, "policies", "policy", ("name", None)),
    (UPTIME, "on-calls", "on-call", ("name", None)),
    (TELEMETRY, "sources", "log source", ("name", "ingesting_host")),
)


def managed_ids():
    out = subprocess.run(
        ["tofu", "show", "-json"], capture_output=True, text=True, check=True
    ).stdout
    root = json.loads(out).get("values", {}).get("root_module", {})
    return {
        str(r["values"].get("id"))
        for r in root.get("resources", [])
        if r["type"].startswith(("betteruptime", "logtail"))
    }


def fetch(base, endpoint, token):
    url = f"{base}/{endpoint}"
    items = []
    while url:
        req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
        try:
            body = json.load(urllib.request.urlopen(req))
        except urllib.error.HTTPError as err:
            # An endpoint this plan does not reach is not worth failing over.
            if err.code in (403, 404):
                return []
            raise
        items += body.get("data", [])
        url = (body.get("pagination") or {}).get("next")
    return items


def line(managed, mark_counter, label, item, name_attr, extra_attr, indent=""):
    attrs = item["attributes"]
    name = attrs.get(name_attr) or "-"
    extra = (attrs.get(extra_attr) or "") if extra_attr else ""
    if item["id"] in managed:
        mark = "managed  "
    else:
        mark = "UNMANAGED"
        mark_counter.append(item["id"])
    print(f"  {mark}  {indent}{label:<14} {item['id']:<9} {name:<26} {extra}")


def main():
    token = os.environ.get("TF_VAR_betterstack_api_token") or os.environ.get(
        "BETTERSTACK_API_TOKEN"
    )
    if not token:
        sys.exit("BETTERSTACK_API_TOKEN is unset; add it to infra/.env")

    managed = managed_ids()
    unmanaged = []

    for base, endpoint, label, attrs in ENDPOINTS:
        for item in fetch(base, endpoint, token):
            line(managed, unmanaged, label, item, *attrs)

            if endpoint != "status-pages":
                continue
            page = item["id"]
            for child, child_label, child_attrs in (
                ("sections", "section", ("name", None)),
                ("resources", "resource", ("public_name", None)),
            ):
                for sub in fetch(UPTIME, f"status-pages/{page}/{child}", token):
                    line(managed, unmanaged, child_label, sub, *child_attrs, indent="  ")

    print()
    print(f"  {len(managed)} managed, {len(unmanaged)} unmanaged")
    if unmanaged:
        print("  Unmanaged resources are invisible to `tofu plan`.")


if __name__ == "__main__":
    main()
