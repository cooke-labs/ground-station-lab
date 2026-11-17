"""Real loopback UDP tests; run: python3 -m unittest discover -s tests -v."""
import json
import pathlib
import socket
import subprocess
import sys
import tempfile
import unittest

APP = pathlib.Path(__file__).resolve().parents[1] / 'app' / 'telemetry_lab.py'


class ReplayTests(unittest.TestCase):
    def exercise(self, duplicates, enforce=False, malformed=False):
        with tempfile.TemporaryDirectory() as directory:
            log = pathlib.Path(directory) / 'events.jsonl'
            capture = pathlib.Path(directory) / 'received.bin'
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
                probe.bind(('127.0.0.1', 0))
                port = probe.getsockname()[1]
            command = [sys.executable, str(APP), 'receive', '--bind', '127.0.0.1', '--port', str(port),
                       '--log', str(log), '--capture', str(capture), '--duration', '5',
                       '--max-events', str(2 + duplicates + int(malformed)), '--source-kind', 'fixture']
            if enforce:
                command.append('--reject-duplicates')
            receiver = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            try:
                self.assertEqual(json.loads(receiver.stdout.readline())['status'], 'listening')
                packet = {'schema_version': 1, 'run_id': 'fixture-run', 'scenario_id': 'fixture',
                          'event_time_utc': '2026-01-01T00:00:00+00:00', 'mission_id': 'fixture-mission',
                          'asset_id': 'fixture-asset', 'sequence': 1}
                payload = json.dumps(packet).encode()
                with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sender:
                    for _ in range(1 + duplicates):
                        sender.sendto(payload, ('127.0.0.1', port))
                    if malformed:
                        sender.sendto(b'{bad json', ('127.0.0.1', port))
                    packet['sequence'] = 2
                    sender.sendto(json.dumps(packet).encode(), ('127.0.0.1', port))
                output, error = receiver.communicate(timeout=8)
                self.assertEqual(receiver.returncode, 0, error)
                self.assertEqual(capture.read_bytes(), payload)
                events = [json.loads(line) for line in log.read_text().splitlines()]
                analysis = json.loads(subprocess.check_output(
                    [sys.executable, str(APP), 'analyze', '--log', str(log)], text=True))
                return events, analysis
            finally:
                if receiver.poll() is None:
                    receiver.kill()
                    receiver.communicate()

    def test_benign_retry_does_not_meet_threshold(self):
        events, analysis = self.exercise(1)
        self.assertEqual(len(events), 3)
        self.assertEqual(analysis['alerts'], [])
        self.assertEqual(analysis['counts']['duplicate_sequence'], 1)

    def test_burst_detected_and_invalid_packet_rejected(self):
        events, analysis = self.exercise(3, malformed=True)
        self.assertEqual(len(analysis['alerts']), 1)
        self.assertEqual(analysis['counts']['invalid_telemetry'], 1)
        self.assertTrue(all(e['outcome'] == 'accepted' for e in events if e['event_type'] == 'duplicate_sequence'))

    def test_mitigation_rejects_duplicates_and_preserves_fresh_telemetry(self):
        events, analysis = self.exercise(3, enforce=True)
        self.assertEqual(len(analysis['alerts']), 1)
        self.assertTrue(all(e['outcome'] == 'rejected' for e in events if e['event_type'] == 'duplicate_sequence'))
        self.assertEqual(sum(e['outcome'] == 'accepted' for e in events), 2)


if __name__ == '__main__':
    unittest.main()
