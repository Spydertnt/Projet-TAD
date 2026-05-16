from pathlib import Path
from xml.sax.saxutils import escape


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "diagrams"


class Svg:
    def __init__(self, width, height, title):
        self.width = width
        self.height = height
        self.parts = [
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
            f'viewBox="0 0 {width} {height}" role="img" aria-label="{escape(title)}">',
            "<defs>",
            '<marker id="arrow" markerWidth="10" markerHeight="10" refX="9" refY="3" orient="auto" markerUnits="strokeWidth">',
            '<path d="M0,0 L0,6 L9,3 z" fill="#334155"/>',
            "</marker>",
            '<filter id="shadow" x="-20%" y="-20%" width="140%" height="140%">',
            '<feDropShadow dx="0" dy="5" stdDeviation="7" flood-color="#0f172a" flood-opacity="0.16"/>',
            "</filter>",
            "</defs>",
            f"<title>{escape(title)}</title>",
            f'<rect x="0" y="0" width="{width}" height="{height}" fill="#f8fafc"/>',
        ]

    def rect(self, x, y, w, h, fill="#ffffff", stroke="#cbd5e1", rx=12, klass=""):
        self.parts.append(
            f'<rect class="{klass}" x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" '
            f'fill="{fill}" stroke="{stroke}" stroke-width="1.4" filter="url(#shadow)"/>'
        )

    def line(self, x1, y1, x2, y2, color="#334155", width=1.6, dash=None, arrow=False):
        dash_attr = f' stroke-dasharray="{dash}"' if dash else ""
        arrow_attr = ' marker-end="url(#arrow)"' if arrow else ""
        self.parts.append(
            f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" '
            f'stroke="{color}" stroke-width="{width}"{dash_attr}{arrow_attr}/>'
        )

    def polyline(self, points, color="#334155", width=1.6, dash=None, arrow=False):
        pts = " ".join(f"{x},{y}" for x, y in points)
        dash_attr = f' stroke-dasharray="{dash}"' if dash else ""
        arrow_attr = ' marker-end="url(#arrow)"' if arrow else ""
        self.parts.append(
            f'<polyline points="{pts}" fill="none" stroke="{color}" stroke-width="{width}"'
            f'{dash_attr}{arrow_attr}/>'
        )

    def text(self, x, y, value, size=14, weight=400, fill="#0f172a", anchor="start"):
        self.parts.append(
            f'<text x="{x}" y="{y}" font-family="Inter, Segoe UI, Arial, sans-serif" '
            f'font-size="{size}" font-weight="{weight}" fill="{fill}" text-anchor="{anchor}">'
            f"{escape(value)}</text>"
        )

    def pill(self, x, y, value, fill="#e0f2fe", stroke="#7dd3fc", color="#075985"):
        w = max(78, len(value) * 7 + 22)
        self.parts.append(
            f'<rect x="{x}" y="{y}" width="{w}" height="26" rx="13" fill="{fill}" stroke="{stroke}"/>'
        )
        self.text(x + w / 2, y + 18, value, 12, 700, color, "middle")
        return w

    def table(self, x, y, w, title, fields, accent="#2563eb"):
        row_h = 22
        h = 42 + row_h * len(fields)
        self.rect(x, y, w, h, "#ffffff", "#cbd5e1", 10)
        self.parts.append(
            f'<rect x="{x}" y="{y}" width="{w}" height="36" rx="10" fill="{accent}" stroke="{accent}"/>'
        )
        self.parts.append(f'<rect x="{x}" y="{y + 25}" width="{w}" height="12" fill="{accent}"/>')
        self.text(x + 12, y + 24, title, 14, 800, "#ffffff")
        for idx, field in enumerate(fields):
            fy = y + 58 + idx * row_h
            self.text(x + 12, fy, field, 12, 500, "#334155")
        return h

    def save(self, path):
        self.parts.append("</svg>")
        Path(path).write_text("\n".join(self.parts), encoding="utf-8")


def generate_architecture():
    svg = Svg(1320, 820, "Architecture Oracle XE distribuee Cergy Pau")
    svg.text(660, 46, "Architecture Oracle XE distribuee - Cergy / Pau", 28, 800, "#0f172a", "middle")
    svg.text(660, 76, "Simulation BDDR locale par deux schemas Oracle et fragmentation par site", 15, 500, "#475569", "middle")

    sites = [
        ("SITE CERGY", 70, 140, "#2563eb"),
        ("SITE PAU", 790, 140, "#0f766e"),
    ]
    for label, x, y, color in sites:
        svg.rect(x, y, 460, 490, "#ffffff", "#cbd5e1", 18)
        svg.text(x + 230, y + 38, label, 22, 800, color, "middle")
        svg.text(x + 230, y + 66, "Schema Oracle local", 14, 600, "#475569", "middle")

        svg.table(x + 35, y + 100, 180, "Tablespaces", [
            "TS_MATERIEL",
            "TS_UTILISATEURS",
            "TS_RESEAU",
            "TS_SUPPORT",
            "TS_INDEX",
        ], color)

        svg.table(x + 245, y + 100, 180, "Donnees locales", [
            "sites",
            "locations",
            "users / groups",
            "assets",
            "tickets",
            "network_ports / IP",
        ], "#64748b")

        svg.table(x + 35, y + 310, 390, "Referentiels exposes", [
            "manufacturers, states",
            "ticket_categories",
        ], "#7c3aed")

    svg.line(535, 315, 785, 315, "#334155", 3, arrow=True)
    svg.line(785, 370, 535, 370, "#334155", 3, arrow=True)
    svg.text(660, 300, "Vues globales", 18, 800, "#0f172a", "middle")
    svg.text(660, 348, "requete distante", 13, 600, "#475569", "middle")
    svg.text(660, 402, "schemas GLPI_CERGY / GLPI_PAU", 13, 600, "#475569", "middle")

    svg.rect(240, 680, 840, 86, "#ecfeff", "#67e8f9", 18)
    svg.text(660, 714, "Regle de distribution", 18, 800, "#0e7490", "middle")
    svg.text(660, 744, "Les lignes operationnelles restent sur leur site selon sites.site_code.", 14, 600, "#155e75", "middle")
    svg.text(660, 766, "Les vues globales interrogent les schemas GLPI_CERGY et GLPI_PAU.", 14, 600, "#155e75", "middle")

    svg.save(OUT / "architecture.svg")


def generate_mcd():
    svg = Svg(1620, 1120, "MCD simplifie GLPI Multi-Sites")
    svg.text(810, 42, "MCD simplifie - BDD GLPI Multi-Sites", 28, 800, "#0f172a", "middle")
    svg.text(810, 72, "Table centrale assets, relations FK classiques et cardinalites lisibles", 15, 500, "#475569", "middle")

    boxes = {
        "sites": (70, 130, 190, "#2563eb", ["PK id", "name", "site_code", "FK parent"]),
        "locations": (330, 130, 190, "#2563eb", ["PK id", "FK site_id", "name", "building / room"]),
        "users": (590, 130, 200, "#0f766e", ["PK id", "login", "FK site_id", "FK location_id"]),
        "profiles": (850, 130, 185, "#0f766e", ["PK id", "name", "interface"]),
        "groups": (1100, 130, 190, "#0f766e", ["PK id", "FK site_id", "name", "FK parent"]),
        "profiles_users": (850, 330, 210, "#0f766e", ["PK id", "FK user_id", "FK profile_id", "FK site_id"]),
        "groups_users": (1100, 330, 205, "#0f766e", ["PK id", "FK user_id", "FK group_id", "is_manager"]),
        "manufacturers": (70, 390, 190, "#7c3aed", ["PK id", "name"]),
        "states": (70, 550, 190, "#7c3aed", ["PK id", "name"]),
        "assets": (380, 470, 260, "#dc2626", ["PK id", "asset_type", "name / serial_number", "FK site/location", "FK owner/tech", "FK refs"]),
        "ticket_categories": (790, 580, 210, "#ea580c", ["PK id", "name", "description"]),
        "tickets": (790, 750, 230, "#ea580c", ["PK id", "FK asset_id", "FK requester", "status / priority"]),
        "ticket_users": (1080, 690, 220, "#ea580c", ["PK id", "FK ticket_id", "FK user_id", "assigned_at"]),
        "ticket_followups": (1080, 870, 220, "#ea580c", ["PK id", "FK ticket_id", "FK user_id", "content"]),
        "network_ports": (420, 760, 235, "#0891b2", ["PK id", "FK asset_id", "mac_address", "port_type"]),
        "ip_networks": (760, 960, 220, "#0891b2", ["PK id", "FK site_id", "network_address", "gateway_address", "vlan_tag"]),
        "ip_addresses": (1260, 960, 220, "#0891b2", ["PK id", "FK port", "FK network", "ip_address"]),
    }

    centers = {}
    for name, (x, y, w, color, fields) in boxes.items():
        h = svg.table(x, y, w, name.upper(), fields, color)
        centers[name] = (x + w / 2, y + h / 2, x, y, w, h)

    def connect(a, b, label, side_a="right", side_b="left", color="#475569", dash=None):
        ca = centers[a]
        cb = centers[b]
        ax = ca[2] + ca[4] if side_a == "right" else ca[2] if side_a == "left" else ca[0]
        ay = ca[3] + ca[5] / 2 if side_a in ("left", "right") else ca[3] if side_a == "top" else ca[3] + ca[5]
        bx = cb[2] if side_b == "left" else cb[2] + cb[4] if side_b == "right" else cb[0]
        by = cb[3] + cb[5] / 2 if side_b in ("left", "right") else cb[3] if side_b == "top" else cb[3] + cb[5]
        midx = (ax + bx) / 2
        midy = (ay + by) / 2
        svg.line(ax, ay, bx, by, color, 1.7, dash=dash, arrow=True)
        svg.rect(midx - 46, midy - 14, 92, 24, "#f8fafc", "#e2e8f0", 8)
        svg.text(midx, midy + 4, label, 11, 700, color, "middle")

    connect("sites", "locations", "1,N")
    connect("sites", "users", "1,N")
    connect("sites", "groups", "1,N")
    connect("users", "profiles_users", "1,N", "right", "left")
    connect("profiles", "profiles_users", "1,N", "bottom", "top")
    connect("users", "groups_users", "1,N", "right", "left")
    connect("groups", "groups_users", "1,N", "bottom", "top")

    connect("locations", "assets", "1,N", "bottom", "top")
    connect("users", "assets", "1,N", "bottom", "top")
    connect("manufacturers", "assets", "1,N")
    connect("states", "assets", "1,N")

    connect("assets", "tickets", "1,N", "right", "left")
    connect("ticket_categories", "tickets", "1,N", "bottom", "top")
    connect("tickets", "ticket_users", "1,N", "right", "left")
    connect("tickets", "ticket_followups", "1,N", "right", "left")
    connect("users", "tickets", "1,N", "bottom", "top", dash="5 5")
    connect("groups", "tickets", "1,N", "bottom", "top", dash="5 5")

    connect("assets", "network_ports", "1,N", "bottom", "top")
    connect("network_ports", "ip_addresses", "1,N", "right", "left", dash="5 5")
    connect("ip_networks", "ip_addresses", "1,N", "right", "left")

    svg.rect(1320, 130, 230, 172, "#ffffff", "#cbd5e1", 14)
    svg.text(1435, 162, "Legende", 18, 800, "#0f172a", "middle")
    svg.pill(1340, 184, "Organisation", "#dbeafe", "#93c5fd", "#1d4ed8")
    svg.pill(1340, 220, "Utilisateurs", "#ccfbf1", "#5eead4", "#0f766e")
    svg.pill(1340, 256, "Inventaire", "#fee2e2", "#fca5a5", "#b91c1c")
    svg.pill(1450, 184, "Support", "#ffedd5", "#fdba74", "#c2410c")
    svg.pill(1450, 220, "Reseau", "#cffafe", "#67e8f9", "#0e7490")
    svg.pill(1450, 256, "Refs", "#ede9fe", "#c4b5fd", "#6d28d9")

    svg.save(OUT / "mcd.svg")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    generate_architecture()
    generate_mcd()
    print(f"Generated: {OUT / 'architecture.svg'}")
    print(f"Generated: {OUT / 'mcd.svg'}")


if __name__ == "__main__":
    main()
