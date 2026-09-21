"""Cross-check the client/server contract that no single-module test can see.

An action the client sends but the router never names, an FX event the server
emits but the client drops, or a pass that is sold while nothing reads it: each
fails silently at runtime, so the player just sees a button that does nothing.
These tests read the real sources and compare them.

Run: python tests/test_contract.py
"""
from __future__ import annotations

from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"


def read(relative: str) -> str:
    return (SRC / relative).read_text(encoding="utf-8-sig")


CLIENT = read("client/init.client.luau")
EFFECTS = read("client/Effects.luau")
AUDIO = read("client/Audio.luau")
BOOTSTRAP = read("server/init.server.luau")
MATCH = read("server/MatchService.luau")
PROFILES = read("server/PlayerService.luau")
CATALOG = read("shared/Catalog.luau")
CONFIG = read("shared/Config.luau")
ALL_SOURCES = {path.name: path.read_text(encoding="utf-8-sig") for path in SRC.rglob("*.luau")}

SERVER_MODULES = (
    "PlayerService", "WorldBuilder", "MatchService", "PartyService",
    "PresenceService", "AnalyticsService", "RejoinService", "ElevatorService",
)


def client_actions() -> set[str]:
    """Every action string the client hands to the Request remote."""
    calls = re.findall(r'(?:^|[^\w.])(?:act|request)\(\s*"([A-Za-z]+)"', CLIENT)
    calls += re.findall(r'self\.request\(\s*"([A-Za-z]+)"', EFFECTS)
    return set(calls)


def server_actions() -> set[str]:
    """Everything the router can dispatch, from all three of its branches."""
    known = set(re.findall(r'action == "([A-Za-z]+)"', BOOTSTRAP))
    known |= table_keys(BOOTSTRAP, "local MATCH_ACTIONS = {")
    known |= table_keys(PROFILES, "local ACTIONS = {")
    known |= set(re.findall(r'action=="([A-Za-z]+)"', MATCH))
    known |= set(re.findall(r'action == "([A-Za-z]+)"', MATCH))
    return known


def table_keys(source: str, opening: str) -> set[str]:
    """Keys of a single-line-or-block Lua table literal, by its opening text."""
    start = source.index(opening) + len(opening)
    end = source.index("}", start)
    return set(re.findall(r"(\w+)\s*=", source[start:end]))


def emitted_fx() -> set[str]:
    kinds: set[str] = set()
    for source in (MATCH, BOOTSTRAP):
        kinds |= set(re.findall(r'kind\s*=\s*"([A-Za-z]+)"', source))
    return kinds


def handled_fx() -> set[str]:
    kinds: set[str] = set()
    for source in (CLIENT, EFFECTS):
        kinds |= set(re.findall(r'event\.kind\s*==\s*"([A-Za-z]+)"', source))
    return kinds


def catalog_passes() -> set[str]:
    block = re.search(r"Passes = \{(.*?)Consumables", CATALOG, re.S)
    assert block, "Passes table not found in the Catalog"
    return set(re.findall(r"(\w+) = \{ id = ", block.group(1)))


def audio_requested_tracks() -> set[str]:
    names: set[str] = set()
    for source in ALL_SOURCES.values():
        names |= set(re.findall(r':(?:Cue|Music)\(\s*"(\w+)"', source))
    return names


class ContractTests(unittest.TestCase):
    # --- request contract ----------------------------------------------------
    def test_every_client_action_reaches_a_server_branch(self):
        missing = sorted(client_actions() - server_actions())
        self.assertEqual(missing, [], f"Client sends actions the server never routes: {missing}")

    def test_match_actions_are_all_implemented_by_the_match(self):
        declared = table_keys(BOOTSTRAP, "local MATCH_ACTIONS = {")
        implemented = set(re.findall(r'action=="([A-Za-z]+)"', MATCH))
        implemented |= set(re.findall(r'action == "([A-Za-z]+)"', MATCH))
        missing = sorted(declared - implemented)
        self.assertEqual(missing, [], f"Routed to the match but unimplemented: {missing}")

    def test_lobby_actions_are_rejected_inside_a_match(self):
        # PlayerService:Handle takes inLobby; the router must pass the real state
        # rather than a constant, or shopping mid-wave would be allowed.
        self.assertIn("profiles:Handle(player, action, payload, not inMatch)", BOOTSTRAP)

    def test_router_answers_every_request_with_the_documented_shape(self):
        router = re.search(r"local function route\(player, action, payload\)(.*?)\nend\n", BOOTSTRAP, re.S)
        self.assertIsNotNone(router, "route() not found in the bootstrap")
        for statement in re.findall(r"return (\{.*?\})", router.group(1), re.S):
            self.assertIn("ok", statement)
        self.assertIn('return { ok = false, message = text("Resposta invalida.', BOOTSTRAP)

    def test_target_priorities_match_between_client_and_server(self):
        """The client used to cycle lowercase priorities the server refused."""
        server = re.search(r'contains\(\{([^}]*)\},payload\.priority\)', MATCH)
        self.assertIsNotNone(server, "MatchService no longer validates SetPriority against a list")
        accepted = set(re.findall(r'"(\w+)"', server.group(1)))
        client = re.search(r'local priorityOrder = \{([^}]*)\}', CLIENT)
        self.assertIsNotNone(client, "the client no longer declares priorityOrder")
        cycled = set(re.findall(r'"(\w+)"', client.group(1)))
        self.assertEqual(cycled, accepted, "the client cycles priorities the server does not accept")
        default = re.search(r'priority="(\w+)"', MATCH)
        self.assertIn(default.group(1), cycled, "a new tower's priority is not one the client can display")

    # --- visual events -------------------------------------------------------
    def test_every_emitted_fx_event_is_handled_by_the_client(self):
        missing = sorted(emitted_fx() - handled_fx())
        self.assertEqual(missing, [], f"Server emits FX the client ignores: {missing}")

    def test_client_reads_no_fx_event_the_server_never_sends(self):
        unused = sorted(handled_fx() - emitted_fx())
        self.assertEqual(unused, [], f"Client waits for FX that never arrive: {unused}")

    # --- monetization integrity ----------------------------------------------
    def test_every_sold_pass_changes_something_in_the_code(self):
        """A pass nobody reads is a pass that sells nothing."""
        for key in sorted(catalog_passes()):
            readers = [
                name for name, source in ALL_SOURCES.items()
                if name != "Catalog.luau" and f"passes.{key}" in source
            ]
            self.assertTrue(readers, f"Pass '{key}' is sold but no module reads passes.{key}")

    def test_gold_packs_declare_an_amount_and_start_unconfigured(self):
        block = re.search(r"Consumables = \{(.*?)\n\t\}", CATALOG, re.S)
        self.assertIsNotNone(block, "Consumables table not found in the Catalog")
        packs = re.findall(r"(\w+) = \{ id = (\d+), price = \d+, gold = (\d+)", block.group(1))
        self.assertTrue(packs, "No gold packs found")
        for key, product_id, gold in packs:
            self.assertEqual(product_id, "0", f"{key} ships with a hardcoded product id")
            self.assertGreater(int(gold), 0, f"{key} grants no gold")

    # --- audio ---------------------------------------------------------------
    def test_audio_tracks_resolve_to_configured_ids(self):
        known = table_keys(AUDIO, "local VOLUME = {")
        configured = table_keys(CONFIG, "Audio = {")
        missing = sorted(known - configured)
        self.assertEqual(missing, [], f"Audio module knows tracks Config cannot supply: {missing}")
        unknown = sorted(audio_requested_tracks() - known)
        self.assertEqual(unknown, [], f"Code asks for tracks the Audio module does not define: {unknown}")

    def test_no_asset_id_is_hardcoded_outside_config(self):
        for name, source in ALL_SOURCES.items():
            if name == "Config.luau":
                continue
            self.assertEqual(
                re.findall(r"rbxassetid://(\d+)", source), [],
                f"{name} hardcodes an asset id instead of reading Config",
            )

    # --- wiring and travel ---------------------------------------------------
    def test_bootstrap_constructs_every_server_module(self):
        for module in SERVER_MODULES:
            self.assertIn(f'require(script:WaitForChild("{module}"))', BOOTSTRAP)
            self.assertTrue((SRC / "server" / f"{module}.luau").is_file(), f"{module} is required but missing")

    def test_client_requires_only_modules_that_exist(self):
        required = set(re.findall(r'require\(script:WaitForChild\("(\w+)"\)\)', CLIENT))
        self.assertTrue(required, "The client entrypoint requires no modules")
        for module in sorted(required):
            self.assertTrue((SRC / "client" / f"{module}.luau").is_file(), f"{module} is required but missing")

    def test_reserved_access_code_never_travels_in_teleport_data(self):
        start = BOOTSTRAP.index("options:SetTeleportData(")
        payload = BOOTSTRAP[start:BOOTSTRAP.index("})", start)]
        self.assertNotIn("accessCode", payload, "The reserved code would be readable by the travelling client")
        self.assertNotIn("seat", payload)

    def test_travel_falls_back_to_standalone_without_configured_places(self):
        self.assertIn('if not travelEnabled then role = "Standalone" end', BOOTSTRAP)
        self.assertIn("not RunService:IsStudio()", BOOTSTRAP)

    def test_shutdown_drains_rewards_before_releasing_profiles(self):
        tail = BOOTSTRAP[BOOTSTRAP.index("game:BindToClose"):]
        self.assertLess(tail.index("match:Drain"), tail.index("profiles:Shutdown"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
