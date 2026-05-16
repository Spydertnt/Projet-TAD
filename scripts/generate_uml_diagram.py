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
            '<filter id="shadow" x="-20%" y="-20%" width="140%" height="140%">',
            '<feDropShadow dx="0" dy="5" stdDeviation="7" flood-color="#0f172a" flood-opacity="0.16"/>',
            "</filter>",
            "</defs>",
            f"<title>{escape(title)}</title>",
            f'<rect x="0" y="0" width="{width}" height="{height}" fill="#f8fafc"/>',
        ]

    def rect(self, x, y, w, h, fill="#ffffff", stroke="#cbd5e1", rx=12):
        self.parts.append(
            f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" '
            f'fill="{fill}" stroke="{stroke}" stroke-width="1.4" filter="url(#shadow)"/>'
        )

    def line(self, x1, y1, x2, y2, color="#334155", width=1.6, dash=None):
        dash_attr = f' stroke-dasharray="{dash}"' if dash else ""
        self.parts.append(
            f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" '
            f'stroke="{color}" stroke-width="{width}"{dash_attr}/>'
        )

    def text(self, x, y, value, size=14, weight=400, fill="#0f172a", anchor="start"):
        self.parts.append(
            f'<text x="{x}" y="{y}" font-family="Inter, Segoe UI, Arial, sans-serif" '
            f'font-size="{size}" font-weight="{weight}" fill="{fill}" text-anchor="{anchor}">'
            f"{escape(value)}</text>"
        )

    def save(self, path):
        self.parts.append("</svg>")
        Path(path).write_text("\n".join(self.parts), encoding="utf-8")


def generate_uml():
    svg = Svg(1600, 980, "Diagramme UML GLPI Multi-Sites")
    svg.text(800, 42, "Diagramme UML - BDD GLPI Multi-Sites", 28, 800, "#0f172a", "middle")
    svg.text(800, 72, "Vue metier du modele cible : classes, attributs principaux et associations", 15, 500, "#475569", "middle")

    def uml_class(x, y, w, name, attrs, methods=None, accent="#2563eb"):
        methods = methods or []
        row_h = 22
        header_h = 36
        attr_h = max(28, row_h * len(attrs) + 12)
        method_h = row_h * len(methods) + (14 if methods else 0)
        h = header_h + attr_h + method_h
        svg.rect(x, y, w, h, "#ffffff", "#cbd5e1", 8)
        svg.parts.append(
            f'<rect x="{x}" y="{y}" width="{w}" height="{header_h}" rx="8" fill="{accent}" stroke="{accent}"/>'
        )
        svg.parts.append(f'<rect x="{x}" y="{y + 24}" width="{w}" height="13" fill="{accent}"/>')
        svg.text(x + w / 2, y + 24, name, 14, 800, "#ffffff", "middle")
        svg.line(x, y + header_h, x + w, y + header_h, "#cbd5e1", 1.2)
        for idx, attr in enumerate(attrs):
            svg.text(x + 12, y + header_h + 22 + idx * row_h, attr, 12, 500, "#334155")
        if methods:
            sep_y = y + header_h + attr_h
            svg.line(x, sep_y, x + w, sep_y, "#cbd5e1", 1.2)
            for idx, method in enumerate(methods):
                svg.text(x + 12, sep_y + 22 + idx * row_h, method, 12, 500, "#334155")
        return h

    boxes = {
        "Site": (60, 120, 210, "#2563eb", ["+ id: NUMBER", "+ name: VARCHAR2", "+ siteCode: VARCHAR2", "+ parent: Site"], []),
        "Location": (330, 120, 220, "#2563eb", ["+ id: NUMBER", "+ name: VARCHAR2", "+ building: VARCHAR2", "+ room: VARCHAR2"], []),
        "User": (610, 120, 230, "#0f766e", ["+ id: NUMBER", "+ login: VARCHAR2", "+ email: VARCHAR2", "+ isActive: NUMBER"], []),
        "Profile": (900, 120, 190, "#0f766e", ["+ id: NUMBER", "+ name: VARCHAR2", "+ interface: VARCHAR2"], []),
        "Group": (1150, 120, 210, "#0f766e", ["+ id: NUMBER", "+ name: VARCHAR2", "+ parent: Group"], []),
        "ProfileUser": (900, 315, 230, "#0f766e", ["+ id: NUMBER", "+ isRecursive: NUMBER"], []),
        "GroupUser": (1180, 315, 220, "#0f766e", ["+ id: NUMBER", "+ isManager: NUMBER"], []),
        "Asset": (380, 390, 270, "#dc2626", ["+ id: NUMBER", "+ assetType: VARCHAR2", "+ name: VARCHAR2", "+ serialNumber: VARCHAR2"], ["+ transferer(siteCible)", "+ archiver()"]),
        "Manufacturer": (60, 610, 210, "#7c3aed", ["+ id: NUMBER", "+ name: VARCHAR2"], []),
        "State": (60, 760, 210, "#7c3aed", ["+ id: NUMBER", "+ name: VARCHAR2"], []),
        "Ticket": (760, 470, 250, "#ea580c", ["+ id: NUMBER", "+ title: VARCHAR2", "+ status: VARCHAR2", "+ priority: VARCHAR2", "+ createdAt: TIMESTAMP"], ["+ affecterTechnicien()", "+ cloturer()"]),
        "TicketCategory": (1070, 510, 220, "#ea580c", ["+ id: NUMBER", "+ name: VARCHAR2", "+ description: VARCHAR2"], []),
        "TicketUser": (760, 720, 250, "#ea580c", ["+ id: NUMBER", "+ assignedBy: User", "+ assignedAt: TIMESTAMP"], []),
        "TicketFollowup": (1070, 720, 230, "#ea580c", ["+ id: NUMBER", "+ content: CLOB", "+ createdAt: TIMESTAMP"], []),
        "NetworkPort": (380, 610, 245, "#0891b2", ["+ id: NUMBER", "+ portName: VARCHAR2", "+ macAddress: VARCHAR2", "+ portType: VARCHAR2"], []),
        "IpNetwork": (820, 815, 240, "#0891b2", ["+ id: NUMBER", "+ networkAddress: VARCHAR2", "+ subnetMask: VARCHAR2", "+ gatewayAddress: VARCHAR2", "+ vlanTag: NUMBER"], []),
        "IpAddress": (1360, 610, 200, "#0891b2", ["+ id: NUMBER", "+ ipAddress: VARCHAR2"], []),
    }

    centers = {}
    for name, (x, y, w, color, attrs, methods) in boxes.items():
        h = uml_class(x, y, w, name, attrs, methods, color)
        centers[name] = (x + w / 2, y + h / 2, x, y, w, h)

    def edge(a, b, mult_a, mult_b, label="", side_a="right", side_b="left", color="#475569", dash=None):
        ca = centers[a]
        cb = centers[b]
        ax = ca[2] + ca[4] if side_a == "right" else ca[2] if side_a == "left" else ca[0]
        ay = ca[3] + ca[5] / 2 if side_a in ("left", "right") else ca[3] if side_a == "top" else ca[3] + ca[5]
        bx = cb[2] if side_b == "left" else cb[2] + cb[4] if side_b == "right" else cb[0]
        by = cb[3] + cb[5] / 2 if side_b in ("left", "right") else cb[3] if side_b == "top" else cb[3] + cb[5]
        svg.line(ax, ay, bx, by, color, 1.6, dash=dash)
        svg.text(ax + (10 if side_a == "right" else -10), ay - 7, mult_a, 11, 700, color, "start" if side_a == "right" else "end")
        svg.text(bx + (-10 if side_b == "left" else 10), by - 7, mult_b, 11, 700, color, "end" if side_b == "left" else "start")
        if label:
            mx = (ax + bx) / 2
            my = (ay + by) / 2
            svg.rect(mx - 58, my - 14, 116, 24, "#f8fafc", "#e2e8f0", 7)
            svg.text(mx, my + 4, label, 11, 700, color, "middle")

    edge("Site", "Location", "1", "0..*", "contient")
    edge("Site", "User", "1", "0..*", "rattache")
    edge("Site", "Group", "1", "0..*", "structure")
    edge("Location", "Asset", "1", "0..*", "localise", "bottom", "top")
    edge("User", "Asset", "0..1", "0..*", "possede", "bottom", "top")
    edge("Manufacturer", "Asset", "1", "0..*", "fabrique")
    edge("State", "Asset", "1", "0..*", "etat")
    edge("User", "ProfileUser", "1", "0..*", "profil", "right", "left")
    edge("Profile", "ProfileUser", "1", "0..*", "", "bottom", "top")
    edge("Group", "GroupUser", "1", "0..*", "", "bottom", "top")
    edge("User", "GroupUser", "1", "0..*", "membre", "right", "left")
    edge("Asset", "Ticket", "0..1", "0..*", "signale", "right", "left")
    edge("TicketCategory", "Ticket", "1", "0..*", "classe", "left", "right")
    edge("Ticket", "TicketUser", "1", "0..*", "participants", "bottom", "top")
    edge("Ticket", "TicketFollowup", "1", "0..*", "suivis", "right", "left")
    edge("User", "Ticket", "1", "0..*", "demandeur", "bottom", "top", dash="5 5")
    edge("Group", "Ticket", "0..1", "0..*", "assigne", "bottom", "top", dash="5 5")
    edge("Asset", "NetworkPort", "1", "0..*", "ports", "bottom", "top")
    edge("NetworkPort", "IpAddress", "0..1", "0..*", "IP", "right", "left", dash="5 5")
    edge("IpNetwork", "IpAddress", "1", "0..*", "", "right", "left")

    svg.rect(1360, 120, 190, 176, "#ffffff", "#cbd5e1", 12)
    svg.text(1455, 152, "Legende UML", 17, 800, "#0f172a", "middle")
    svg.text(1380, 184, "+ attribut public", 12, 600, "#334155")
    svg.text(1380, 210, "0..* multiplicite", 12, 600, "#334155")
    svg.line(1380, 236, 1450, 236, "#475569", 1.6)
    svg.text(1462, 240, "association", 12, 600, "#334155")
    svg.line(1380, 266, 1450, 266, "#475569", 1.6, dash="5 5")
    svg.text(1462, 270, "lien secondaire", 12, 600, "#334155")
    svg.save(OUT / "uml.svg")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    generate_uml()
    print(f"Generated: {OUT / 'uml.svg'}")


if __name__ == "__main__":
    main()
