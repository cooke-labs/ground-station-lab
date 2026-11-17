#!/usr/bin/env python3
"""Bounded synthetic UDP exercise; duplicate detection is not authentication."""
import argparse
import collections
import datetime
import hashlib
import ipaddress
import json
import pathlib
import socket
import time
import uuid


def utc():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def digest(data):
    return hashlib.sha256(data).hexdigest()


def destination(value):
    address = ipaddress.ip_address(value)
    if address.version != 4 or not (address in ipaddress.ip_network('10.42.0.0/16') or address.is_loopback):
        raise argparse.ArgumentTypeError('Destination must be owned lab 10.42.0.0/16 or loopback IPv4.')
    return value


def integer(low, high):
    def parse(value):
        result = int(value)
        if not low <= result <= high:
            raise argparse.ArgumentTypeError(f'Expected {low}..{high}')
        return result
    return parse


def receive(args):
    seen = set()
    deadline = time.monotonic() + args.duration
    count = 0
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock, open(args.log, 'w', encoding='utf-8') as log:
        sock.bind((args.bind, args.port))
        sock.settimeout(0.5)
        print(json.dumps({'status': 'listening', 'port': args.port, 'time_utc': utc()}), flush=True)
        while time.monotonic() < deadline and count < args.max_events:
            try:
                data, source = sock.recvfrom(4097)
            except socket.timeout:
                continue
            count += 1
            event = {'schema_version': 1, 'event_id': str(uuid.uuid4()), 'observed_time_utc': utc(),
                     'src_ip': source[0], 'src_port': source[1], 'dst_ip': args.bind, 'dst_port': args.port,
                     'protocol': 'UDP', 'source_kind': args.source_kind, 'payload_sha256': digest(data),
                     'event_type': 'invalid_telemetry', 'outcome': 'rejected', 'reason': 'invalid_schema'}
            try:
                if len(data) > 4096:
                    raise ValueError('oversize')
                packet = json.loads(data)
                if not isinstance(packet, dict) or packet.get('schema_version') != 1:
                    raise ValueError('schema')
                for field in ('run_id', 'scenario_id', 'event_time_utc', 'mission_id', 'asset_id'):
                    if not isinstance(packet.get(field), str) or not 1 <= len(packet[field]) <= 128:
                        raise ValueError(field)
                if type(packet.get('sequence')) is not int or not 0 <= packet['sequence'] <= 1000000:
                    raise ValueError('sequence')
                event.update({key: packet[key] for key in ('run_id', 'scenario_id', 'event_time_utc', 'mission_id', 'asset_id', 'sequence')})
                key = (source[0], packet['mission_id'], packet['asset_id'], packet['sequence'])
                duplicate = key in seen
                seen.add(key)
                event.update(event_type='duplicate_sequence' if duplicate else 'telemetry',
                             outcome='rejected' if duplicate and args.reject_duplicates else 'accepted',
                             reason='sequence_seen' if duplicate else 'first_seen')
                if args.capture and not pathlib.Path(args.capture).exists():
                    pathlib.Path(args.capture).write_bytes(data)
            except (ValueError, TypeError, UnicodeError):
                pass
            log.write(json.dumps(event, separators=(',', ':')) + '\n')
            log.flush()
        print(json.dumps({'status': 'finished', 'events': count, 'time_utc': utc()}), flush=True)


def transmit(args):
    if args.command == 'replay':
        payload = pathlib.Path(args.capture).read_bytes()
        if not 1 <= len(payload) <= 4096:
            raise ValueError('Capture must contain one payload of 1..4096 bytes')
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        for index in range(args.count):
            if args.command == 'send':
                packet = {'schema_version': 1, 'run_id': args.run_id, 'scenario_id': 'S1',
                          'event_time_utc': utc(), 'mission_id': 'synthetic-mission', 'asset_id': args.asset,
                          'sequence': args.start_sequence + index, 'temperature_c': 20 + index}
                payload = json.dumps(packet, separators=(',', ':')).encode()
                if index == 0 and args.capture:
                    pathlib.Path(args.capture).write_bytes(payload)
            sock.sendto(payload, (args.destination, args.port))
            print(json.dumps({'action': args.command, 'time_utc': utc(), 'payload_sha256': digest(payload),
                              'bytes': len(payload), 'destination': args.destination, 'port': args.port}), flush=True)
            if index < args.count - 1:
                time.sleep(args.interval)


def analyze(args):
    windows = collections.defaultdict(collections.deque)
    alerts = []
    counts = collections.Counter()
    with open(args.log, encoding='utf-8') as log:
        for line in log:
            event = json.loads(line)
            counts[event['event_type']] += 1
            if event['event_type'] != 'duplicate_sequence':
                continue
            key = (event['src_ip'], event['mission_id'], event['asset_id'])
            timestamp = datetime.datetime.fromisoformat(event['observed_time_utc']).timestamp()
            window = windows[key]
            while window and timestamp - window[0] > args.window_seconds:
                window.popleft()
            window.append(timestamp)
            if len(window) == args.threshold:
                alerts.append({'event_type': 'replay_candidate', 'observed_time_utc': event['observed_time_utc'],
                               'src_ip': key[0], 'mission_id': key[1], 'asset_id': key[2],
                               'duplicate_count': len(window), 'window_seconds': args.window_seconds,
                               'trigger_event_id': event['event_id'], 'confidence': 'duplicate behavior; intent requires investigation'})
    print(json.dumps({'rule': 'D1', 'threshold': args.threshold, 'window_seconds': args.window_seconds,
                      'counts': dict(counts), 'alerts': alerts}, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    receiver = commands.add_parser('receive')
    receiver.add_argument('--bind', type=destination, required=True)
    receiver.add_argument('--port', type=integer(1024, 65535), default=5514)
    receiver.add_argument('--log', required=True)
    receiver.add_argument('--capture')
    receiver.add_argument('--duration', type=integer(1, 3600), default=900)
    receiver.add_argument('--max-events', type=integer(1, 10000), default=1000)
    receiver.add_argument('--reject-duplicates', action='store_true')
    receiver.add_argument('--source-kind', choices=['live_lab', 'fixture'], default='live_lab')
    receiver.set_defaults(func=receive)
    for name in ('send', 'replay'):
        sender = commands.add_parser(name)
        sender.add_argument('--destination', type=destination, required=True)
        sender.add_argument('--port', type=integer(1024, 65535), default=5514)
        sender.add_argument('--count', type=integer(1, 100), default=1)
        sender.add_argument('--interval', type=integer(1, 30), default=1)
        sender.add_argument('--capture', required=name == 'replay')
        if name == 'send':
            sender.add_argument('--run-id', default=str(uuid.uuid4()))
            sender.add_argument('--asset', default='synthetic-sat-01')
            sender.add_argument('--start-sequence', type=integer(0, 999900), default=1)
        sender.set_defaults(func=transmit)
    analyzer = commands.add_parser('analyze')
    analyzer.add_argument('--log', required=True)
    analyzer.add_argument('--threshold', type=integer(2, 100), default=3)
    analyzer.add_argument('--window-seconds', type=integer(1, 300), default=10)
    analyzer.set_defaults(func=analyze)
    args = parser.parse_args()
    args.func(args)


if __name__ == '__main__':
    main()
