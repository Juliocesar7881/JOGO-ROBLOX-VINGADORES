"""Build self-contained Roblox XML places using only Python's standard library.

Run: python tools/build.py
Open dist/Doomsday-Studio.rbxlx in Roblox Studio and press Play.
Source modules are embedded as script Source, never downloaded at runtime.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
from pathlib import Path
import struct
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]
ROLES = {"Studio": "Standalone", "Lobby": "Lobby", "Match": "Match", "Afk": "Afk"}


def prop(parent: ET.Element, kind: str, name: str, value: object) -> ET.Element:
    item = ET.SubElement(parent, kind, {"name": name})
    if isinstance(value, bool):
        item.text = "true" if value else "false"
    else:
        item.text = str(value)
    return item


def item(parent: ET.Element, class_name: str, name: str) -> tuple[ET.Element, ET.Element]:
    element = ET.SubElement(parent, "Item", {"class": class_name, "referent": "RBX" + hashlib.sha256((class_name + name + str(len(parent))).encode()).hexdigest()[:20]})
    properties = ET.SubElement(element, "Properties")
    prop(properties, "string", "Name", name)
    return element, properties


def color(properties: ET.Element, name: str, rgb: tuple[float, float, float]) -> None:
    element = ET.SubElement(properties, "Color3", {"name": name})
    for channel, value in zip(("R", "G", "B"), rgb):
        ET.SubElement(element, channel).text = str(value)


def vector3(properties: ET.Element, name: str, value: tuple[float, float, float]) -> None:
    element = ET.SubElement(properties, "Vector3", {"name": name})
    for axis, number in zip(("X", "Y", "Z"), value):
        ET.SubElement(element, axis).text = str(float(number))


def coordinate_frame(properties: ET.Element, name: str, position: tuple[float, float, float]) -> None:
    """An axis-aligned CFrame: the identity rotation plus a translation."""
    element = ET.SubElement(properties, "CoordinateFrame", {"name": name})
    for axis, number in zip(("X", "Y", "Z"), position):
        ET.SubElement(element, axis).text = str(float(number))
    identity = {"R00": 1, "R01": 0, "R02": 0, "R10": 0, "R11": 1, "R12": 0, "R20": 0, "R21": 0, "R22": 1}
    for key, number in identity.items():
        ET.SubElement(element, key).text = str(float(number))


def color3uint8(properties: ET.Element, name: str, rgb: tuple[int, int, int]) -> None:
    red, green, blue = rgb
    packed = (255 << 24) | (red << 16) | (green << 8) | blue
    ET.SubElement(properties, "Color3uint8", {"name": name}).text = str(packed)


def attributes(values: dict[str, str]) -> str:
    """Roblox AttributesSerialize: count, length-prefixed names, string values."""
    def string(value: str) -> bytes:
        raw = value.encode("utf-8")
        return struct.pack("<I", len(raw)) + raw
    data = struct.pack("<I", len(values))
    for name, value in values.items():
        data += string(name) + bytes([2]) + string(value)
    return base64.b64encode(data).decode("ascii")


def source_entries(root: Path = ROOT) -> list[Path]:
    paths = sorted((root / "src").rglob("*.luau"))
    mandatory = ["shared/Catalog.luau", "shared/Config.luau", "shared/Rules.luau", "shared/Waves.luau", "server/PlayerService.luau", "server/MatchService.luau", "server/WorldBuilder.luau"]
    missing = [str(path) for name in mandatory if not (path := root / "src" / name).is_file()]
    if missing:
        raise ValueError("Missing required sources: " + ", ".join(missing))
    if not any(path.name.endswith(".server.luau") for path in paths):
        raise ValueError("Missing server bootstrap (*.server.luau)")
    if not any(path.name.endswith(".client.luau") for path in paths):
        raise ValueError("Missing client entrypoint (*.client.luau)")
    for path in paths:
        if not path.read_text(encoding="utf-8-sig").strip():
            raise ValueError(f"Empty source file: {path}")
    return paths


def build_tree(role: str, root: Path = ROOT) -> ET.Element:
    if role not in ROLES.values():
        raise ValueError(f"Unknown place role: {role}")
    paths = source_entries(root)
    tree = ET.Element("roblox", {"version": "4", "xmlns:xmime": "http://www.w3.org/2005/05/xmlmime", "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance"})
    ET.SubElement(tree, "External").text = "null"
    ET.SubElement(tree, "External").text = "nil"

    workspace, workspace_properties = item(tree, "Workspace", "Workspace")
    prop(workspace_properties, "float", "Gravity", 196.2)
    prop(workspace_properties, "bool", "StreamingEnabled", False)
    prop(workspace_properties, "BinaryString", "AttributesSerialize", attributes({"DoomRole": role}))

    # Every map and the lobby are generated at run time, which left the editor
    # viewport completely empty and made an opened place look broken. These two
    # parts give the editor something to stand on; the bootstrap deletes them by
    # name the moment the real world is built.
    ground, ground_properties = item(workspace, "Part", "EditorBaseplate")
    vector3(ground_properties, "size", (512, 4, 512))
    coordinate_frame(ground_properties, "CFrame", (0, -2, 0))
    color3uint8(ground_properties, "Color3uint8", (31, 42, 52))
    prop(ground_properties, "bool", "Anchored", True)
    prop(ground_properties, "token", "Material", 816)  # Slate
    prop(ground_properties, "token", "TopSurface", 0)
    prop(ground_properties, "token", "BottomSurface", 0)

    spawn, spawn_properties = item(workspace, "SpawnLocation", "EditorSpawn")
    vector3(spawn_properties, "size", (24, 1, 24))
    coordinate_frame(spawn_properties, "CFrame", (0, 0.5, 340))
    color3uint8(spawn_properties, "Color3uint8", (111, 247, 167))
    prop(spawn_properties, "bool", "Anchored", True)
    prop(spawn_properties, "bool", "Neutral", True)
    prop(spawn_properties, "float", "Duration", 0)
    prop(spawn_properties, "token", "TopSurface", 0)
    prop(spawn_properties, "token", "BottomSurface", 0)

    lighting, lighting_properties = item(tree, "Lighting", "Lighting")
    # Technology is RobloxScript-protected at runtime; author Future in the file.
    prop(lighting_properties, "token", "Technology", 4)
    prop(lighting_properties, "float", "Brightness", 2)
    prop(lighting_properties, "float", "ClockTime", 18)
    prop(lighting_properties, "bool", "GlobalShadows", True)
    color(lighting_properties, "Ambient", (0.26, 0.30, 0.37))
    color(lighting_properties, "OutdoorAmbient", (0.32, 0.37, 0.45))
    prop(lighting_properties, "float", "FogEnd", 1000)

    replicated, _ = item(tree, "ReplicatedStorage", "ReplicatedStorage")
    def source_container(parent: ET.Element, name: str, area: str) -> ET.Element:
        directory = root / "src" / area
        init_server = directory / "init.server.luau"
        init_client = directory / "init.client.luau"
        init_module = directory / "init.luau"
        init_path = next((path for path in (init_server, init_client, init_module) if path.exists()), None)
        if init_path is None:
            return item(parent, "Folder", name)[0]
        class_name = "Script" if init_path == init_server else "LocalScript" if init_path == init_client else "ModuleScript"
        container, properties = item(parent, class_name, name)
        source = init_path.read_text(encoding="utf-8-sig")
        if class_name == "Script":
            source = f'-- Place role embedded by tools/build.py\nworkspace:SetAttribute("DoomRole", "{role}")\n' + source
        prop(properties, "ProtectedString", "Source", source)
        if class_name != "ModuleScript":
            prop(properties, "bool", "Disabled", False)
        return container

    shared = source_container(replicated, "DoomShared", "shared")
    remotes, _ = item(replicated, "Folder", "DoomRemotes")
    item(remotes, "RemoteFunction", "Request")
    item(remotes, "RemoteEvent", "State")
    item(remotes, "RemoteEvent", "FX")
    server_service, _ = item(tree, "ServerScriptService", "ServerScriptService")
    server = source_container(server_service, "DoomServer", "server")
    starter, starter_properties = item(tree, "StarterPlayer", "StarterPlayer")
    prop(starter_properties, "bool", "LoadCharacterAppearance", False)
    prop(starter_properties, "float", "CameraMaxZoomDistance", 110)
    prop(starter_properties, "float", "CameraMinZoomDistance", 8)
    starter_scripts, _ = item(starter, "StarterPlayerScripts", "StarterPlayerScripts")
    client = source_container(starter_scripts, "DoomClient", "client")
    item(tree, "StarterGui", "StarterGui")
    item(tree, "SoundService", "SoundService")
    # Older XML defaults select legacy chat. Author the modern filtered chat
    # service in the place; ChatVersion is not writable by game scripts.
    _, chat_properties = item(tree, "TextChatService", "TextChatService")
    prop(chat_properties, "token", "ChatVersion", 1)
    prop(chat_properties, "bool", "CreateDefaultTextChannels", True)
    prop(chat_properties, "bool", "CreateDefaultCommands", True)
    containers = {"shared": shared, "server": server, "client": client}
    folders: dict[tuple[str, ...], ET.Element] = {}

    for path in paths:
        relative = path.relative_to(root / "src")
        if len(relative.parts) == 2 and path.name in {"init.server.luau", "init.client.luau", "init.luau"}:
            continue  # Already embedded in its Rojo-style source container.
        if relative.parts[0] not in containers:
            raise ValueError(f"Unknown source area: {relative}")
        container = containers[relative.parts[0]]
        for depth, directory in enumerate(relative.parts[1:-1], 2):
            key = relative.parts[:depth]
            if key not in folders:
                folders[key], _ = item(container, "Folder", directory)
            container = folders[key]
        if path.name.endswith(".server.luau"):
            class_name, script_name = "Script", path.name.removesuffix(".server.luau")
        elif path.name.endswith(".client.luau"):
            class_name, script_name = "LocalScript", path.name.removesuffix(".client.luau")
        else:
            class_name, script_name = "ModuleScript", path.stem
        _, properties = item(container, class_name, script_name)
        source = path.read_text(encoding="utf-8-sig")
        if class_name == "Script":
            # Set before bootstrap even when an editor/importer omits attributes.
            source = f'-- Place role embedded by tools/build.py\nworkspace:SetAttribute("DoomRole", "{role}")\n' + source
        prop(properties, "ProtectedString", "Source", source)
        if class_name in {"Script", "LocalScript"}:
            prop(properties, "bool", "Disabled", False)
    return tree


def build(output: Path, root: Path = ROOT) -> list[Path]:
    paths = source_entries(root)
    output.mkdir(parents=True, exist_ok=True)
    products = []
    for suffix, role in ROLES.items():
        path = output / f"Doomsday-{suffix}.rbxlx"
        tree = build_tree(role, root)
        ET.indent(tree, space="  ")
        ET.ElementTree(tree).write(path, encoding="utf-8", xml_declaration=True)
        products.append(path)
    manifest = {
        "format": 1,
        "sources": {str(path.relative_to(root)).replace("\\", "/"): hashlib.sha256(path.read_bytes()).hexdigest() for path in paths},
        "artifacts": {path.name: {"role": ROLES[path.stem.removeprefix("Doomsday-")], "sha256": hashlib.sha256(path.read_bytes()).hexdigest()} for path in products},
    }
    (output / "build-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return products


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "dist")
    parser.add_argument("--check", action="store_true", help="Validate source layout without generating places")
    options = parser.parse_args()
    if options.check:
        paths = source_entries()
        print(f"Validated {len(paths)} nonempty source files")
        return
    for path in build(options.output):
        print(f"Built {path.relative_to(ROOT) if path.is_relative_to(ROOT) else path} ({path.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
