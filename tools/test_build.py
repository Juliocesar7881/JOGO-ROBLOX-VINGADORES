"""Integrity tests for generated native Roblox places; no Studio claim is implied."""
from __future__ import annotations

import base64
import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest
import xml.etree.ElementTree as ET

import build


class NativePlaceTests(unittest.TestCase):
    def test_modern_chat_is_authored_in_all_places(self):
        for role in build.ROLES.values():
            tree = build.build_tree(role)
            props = tree.find("Item[@class='TextChatService']/Properties")
            self.assertIsNotNone(props)
            self.assertEqual(props.find("token[@name='ChatVersion']").text, "1")
            self.assertEqual(props.find("bool[@name='CreateDefaultTextChannels']").text, "true")

    def test_renderer_is_authored_without_protected_runtime_writes(self):
        for role in build.ROLES.values():
            tree = build.build_tree(role)
            technology = tree.find("Item[@class='Lighting']/Properties/token[@name='Technology']")
            self.assertIsNotNone(technology)
            self.assertEqual(technology.text, "4")
        source = (build.ROOT / "src/server/WorldBuilder.luau").read_text(encoding="utf-8")
        self.assertNotIn("lighting.Technology", source)

    def test_every_source_embedded_once_and_scripts_enabled(self):
        sources = [path.read_text(encoding="utf-8-sig") for path in build.source_entries()]
        for role in build.ROLES.values():
            tree = build.build_tree(role)
            embedded = [prop.text or "" for prop in tree.findall(".//ProtectedString[@name='Source']")]
            self.assertEqual(len(sources), len(embedded))
            for source in sources:
                self.assertEqual(sum(text.endswith(source) for text in embedded), 1, "Source must appear once")
            refs = [node.attrib["referent"] for node in tree.findall(".//Item")]
            self.assertEqual(len(refs), len(set(refs)), "Referents must be unique")
            for script in tree.findall(".//Item[@class='Script']") + tree.findall(".//Item[@class='LocalScript']"):
                self.assertEqual(script.find("Properties/bool[@name='Disabled']").text, "false")

    def test_role_attribute_matches_bootstrap(self):
        for role in build.ROLES.values():
            tree = build.build_tree(role)
            encoded = tree.find("Item[@class='Workspace']/Properties/BinaryString[@name='AttributesSerialize']").text
            data = base64.b64decode(encoded)
            self.assertEqual(struct.unpack_from("<I", data, 0)[0], 1)
            size = struct.unpack_from("<I", data, 4)[0]
            self.assertEqual(data[8:8 + size], b"DoomRole")
            self.assertEqual(data[8 + size], 2)
            value_size = struct.unpack_from("<I", data, 9 + size)[0]
            self.assertEqual(data[13 + size:13 + size + value_size].decode(), role)
            for source in tree.findall(".//Item[@class='Script']/Properties/ProtectedString[@name='Source']"):
                self.assertIn(f'workspace:SetAttribute("DoomRole", "{role}")', source.text)

    def test_client_init_uses_rojo_parenting(self):
        tree = build.build_tree("Standalone")
        client = tree.find(".//Item[@class='StarterPlayerScripts']/Item")
        self.assertEqual(client.attrib["class"], "LocalScript")
        self.assertEqual(client.find("Properties/string[@name='Name']").text, "DoomClient")
        modules = {item.find("Properties/string[@name='Name']").text for item in client.findall("Item[@class='ModuleScript']")}
        self.assertTrue({"UI", "Effects"}.issubset(modules))

    def test_deterministic_artifacts_and_source_hash_manifest(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            first = build.build(output)
            old = {path.name: path.read_bytes() for path in first}
            second = build.build(output)
            self.assertEqual(old, {path.name: path.read_bytes() for path in second})
            manifest = json.loads((output / "build-manifest.json").read_text(encoding="utf-8"))
            self.assertEqual(len(manifest["sources"]), len(build.source_entries()))
            for path in second:
                ET.parse(path)
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), manifest["artifacts"][path.name]["sha256"])

    def test_missing_sources_fail_closed(self):
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaises(ValueError):
                build.source_entries(Path(temporary))

    def test_three_rojo_manifests_reference_existing_source_areas(self):
        for filename, role in (("default.project.json", "Standalone"), ("lobby.project.json", "Lobby"), ("match.project.json", "Match")):
            project = json.loads((build.ROOT / filename).read_text(encoding="utf-8"))
            self.assertEqual(project["tree"]["Workspace"]["$attributes"]["DoomRole"], role)
            for area in ("shared", "server", "client", "first"):
                self.assertTrue((build.ROOT / "src" / area).is_dir())


ART_MODEL = """<roblox version="4">
  <Item class="Model" referent="RBX1">
    <Properties>
      <string name="Name">IronManFinal</string>
      <Ref name="PrimaryPart">RBX2</Ref>
    </Properties>
    <Item class="MeshPart" referent="RBX2">
      <Properties><string name="Name">Body</string><SharedString name="PhysicalConfigData">abc123</SharedString></Properties>
      <Item class="Attachment" referent="RBX3"><Properties><string name="Name">Muzzle</string></Properties></Item>
    </Item>
    %s
  </Item>
  <SharedStrings><SharedString md5="abc123">AAAA</SharedString></SharedStrings>
</roblox>
"""


def write_art(folder: Path, extra: str = "", manifest: dict | None = None) -> None:
    (folder / "heroes").mkdir(parents=True, exist_ok=True)
    (folder / "heroes" / "ironman.rbxmx").write_text(ART_MODEL % extra, encoding="utf-8")
    if manifest is None:
        manifest = {"heroes": {"ironman": {"file": "heroes/ironman.rbxmx", "author": "Voidhb8", "permission": "own work"}}}
    (folder / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")


class ArtPipelineTests(unittest.TestCase):
    def test_art_is_embedded_with_unique_referents_and_shared_strings(self):
        with tempfile.TemporaryDirectory() as temporary:
            art = Path(temporary)
            write_art(art)
            tree = build.build_tree("Standalone", art_root=art)
            folder = tree.find(".//Item[@class='ReplicatedStorage']/Item[@class='Folder']/Properties/string[@name='Name']")
            names = [node.find("Properties/string[@name='Name']").text for node in tree.findall(".//Item[@class='ReplicatedStorage']//Item")]
            self.assertIn("DoomArt", names)
            self.assertIn("Heroes", names)
            model = next(node for node in tree.iter("Item") if node.attrib["class"] == "Model" and node.find("Properties/string[@name='Name']").text == "ironman")
            refs = [node.attrib["referent"] for node in tree.iter("Item")]
            self.assertEqual(len(refs), len(set(refs)), "art referents stay unique in the place")
            body = model.find("Item[@class='MeshPart']")
            self.assertEqual(model.find("Properties/Ref[@name='PrimaryPart']").text, body.attrib["referent"], "PrimaryPart follows its renamed part")
            shared = tree.findall("SharedStrings/SharedString")
            self.assertEqual([entry.attrib["md5"] for entry in shared], ["abc123"])
            self.assertIsNotNone(folder)

    def test_art_with_a_script_is_refused(self):
        with tempfile.TemporaryDirectory() as temporary:
            art = Path(temporary)
            write_art(art, '<Item class="Script" referent="RBX9"><Properties><string name="Name">Sneaky</string></Properties></Item>')
            with self.assertRaises(ValueError):
                build.build_tree("Standalone", art_root=art)

    def test_art_without_author_or_permission_is_refused(self):
        with tempfile.TemporaryDirectory() as temporary:
            art = Path(temporary)
            write_art(art, manifest={"heroes": {"ironman": {"file": "heroes/ironman.rbxmx", "author": "", "permission": "own work"}}})
            with self.assertRaises(ValueError):
                build.build_tree("Standalone", art_root=art)
        with tempfile.TemporaryDirectory() as temporary:
            art = Path(temporary)
            write_art(art, manifest={"heroes": {}})
            with self.assertRaises(ValueError):
                build.build_tree("Standalone", art_root=art)

    def test_no_art_changes_nothing(self):
        with tempfile.TemporaryDirectory() as temporary:
            tree = build.build_tree("Standalone", art_root=Path(temporary))
            self.assertIsNone(tree.find("SharedStrings"))
            names = [node.find("Properties/string[@name='Name']").text for node in tree.iter("Item")]
            self.assertNotIn("DoomArt", names)


if __name__ == "__main__":
    unittest.main(verbosity=2)
