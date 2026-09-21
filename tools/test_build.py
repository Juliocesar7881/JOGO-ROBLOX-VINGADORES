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
            for area in ("shared", "server", "client"):
                self.assertTrue((build.ROOT / "src" / area).is_dir())


if __name__ == "__main__":
    unittest.main(verbosity=2)
