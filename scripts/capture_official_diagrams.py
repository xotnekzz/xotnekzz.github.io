"""Collect selected architecture figures from upstream documentation.

Usage: python3 scripts/capture_official_diagrams.py discover
       python3 scripts/capture_official_diagrams.py download

The manifest records each original source and image URL for attribution.
"""

from argparse import ArgumentParser
from html.parser import HTMLParser
import json
from pathlib import Path
from urllib.parse import urljoin, urlparse
from urllib.request import Request, urlopen


PAGES = {
    "airflow": "https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/overview.html",
    "doris": "https://doris.apache.org/docs/4.x/features-architecture/system-architecture/",
    "seaweedfs": "https://github.com/seaweedfs/seaweedfs/blob/master/README.md",
    "dbt": "https://docs.getdbt.com/docs/build/projects",
    "airbyte": "https://github.com/airbytehq/airbyte/blob/master/docs/platform/understanding-airbyte/high-level-view.md",
    "duckdb": "https://duckdb.org/docs/current/internals/overview",
    "spark": "https://spark.apache.org/docs/latest/cluster-overview.html",
    "flink": "https://nightlies.apache.org/flink/flink-docs-stable/docs/concepts/flink-architecture/",
    "kafka": "https://kafka.apache.org/41/design/design/",
    "nifi": "https://nifi.apache.org/docs/nifi-docs/html/overview",
}

# Filled after reviewing discover output. An empty value means the page has
# no suitable architecture figure and the authored SVG remains the illustration.
SELECTED = {
    "airflow": "https://airflow.apache.org/docs/apache-airflow/stable/_images/diagram_distributed_airflow_architecture.png",
    "doris": "https://cdnd.selectdb.com/assets/images/compute-storage-coupled-c168e29d3299982489174992208ad3af.jpg",
    "seaweedfs": "https://raw.githubusercontent.com/seaweedfs/seaweedfs/master/note/SeaweedFS_Architecture.png",
    "spark": "https://spark.apache.org/docs/latest/img/cluster-overview.png",
    "flink": "https://nightlies.apache.org/flink/flink-docs-release-2.3//fig/processes.svg",
    "nifi": "https://nifi.apache.org/docs/nifi-docs/html/images/zero-leader-node.png",
}


class Images(HTMLParser):
    def __init__(self):
        super().__init__()
        self.images = []

    def handle_starttag(self, tag, attrs):
        if tag != "img":
            return
        values = dict(attrs)
        if values.get("src"):
            self.images.append({"alt": values.get("alt", ""), "src": values["src"]})


def fetch(url):
    req = Request(url, headers={"User-Agent": "Mozilla/5.0 (documentation research)"})
    with urlopen(req, timeout=30) as response:
        return response.read(), response.headers.get_content_type()


def discover():
    for slug, page in PAGES.items():
        try:
            body, _ = fetch(page)
            parser = Images()
            parser.feed(body.decode("utf-8", errors="replace"))
            entries = [{"alt": item["alt"], "url": urljoin(page, item["src"])} for item in parser.images]
            print(json.dumps({"slug": slug, "page": page, "images": entries}, ensure_ascii=False))
        except Exception as exc:
            print(json.dumps({"slug": slug, "error": str(exc)}, ensure_ascii=False))


def download():
    output = Path(__file__).resolve().parents[1] / "public/images/posts/data-platform-theory/official"
    output.mkdir(parents=True, exist_ok=True)
    manifest = []
    for slug, url in SELECTED.items():
        body, mime = fetch(url)
        if not mime.startswith("image/"):
            raise ValueError(f"{slug}: expected image, received {mime}")
        suffix = Path(urlparse(url).path).suffix.lower() or ".png"
        filename = f"{slug}-official{suffix}"
        (output / filename).write_bytes(body)
        manifest.append({"slug": slug, "file": filename, "source_page": PAGES[slug], "image_url": url, "mime": mime})
        print(f"{slug}: {filename} ({len(body)} bytes)")
    (output / "sources.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    parser = ArgumentParser()
    parser.add_argument("mode", choices=["discover", "download"])
    args = parser.parse_args()
    (discover if args.mode == "discover" else download)()
