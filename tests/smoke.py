#!/usr/bin/env python3
"""Offline socket-level checks; no Google app, account, or Internet required."""
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]


def read_exact(connection, count):
    result = b''
    while len(result) < count:
        data = connection.recv(count - len(result))
        if not data:
            raise RuntimeError('Unexpected end of SOCKS handshake')
        result += data
    return result


def listener():
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.bind(('127.0.0.1', 0))
    sock.listen(2)
    sock.settimeout(10)
    return sock


with tempfile.TemporaryDirectory(prefix='gemini-notun-smoke-') as temp:
    temp = Path(temp)
    library = temp / 'libgemini_proxy_lab.dylib'
    probe = temp / 'Gemini'  # The interposer intentionally targets this name.
    subprocess.run(['xcrun', 'clang++', '-std=c++17', '-O2', '-dynamiclib',
                    '-I', str(root / 'include'), str(root / 'src/main_mac.cpp'),
                    str(root / 'src/hooks/HooksMac.cpp'), '-o', str(library)], check=True)
    subprocess.run(['xcrun', 'clang', str(root / 'tests/probe.c'), '-o', str(probe)], check=True)
    env = os.environ.copy()
    env['DYLD_INSERT_LIBRARIES'] = str(library)

    # The proxy emulates just enough SOCKS5 to inspect the destination.
    with listener() as proxy:
        port = proxy.getsockname()[1]
        (temp / 'config.json').write_text(json.dumps({
            'proxy': {'type': 'socks5', 'host': '127.0.0.1', 'port': port},
            'fake_ip': {'enabled': False}, 'target_processes': ['Gemini'],
            'updates': {'enabled': False}, 'log_level': 'error',
        }), encoding='utf-8')
        proc = subprocess.Popen([str(probe), '198.51.100.12', '443'], env=env)
        with proxy.accept()[0] as connection:
            connection.settimeout(10)
            assert read_exact(connection, 3) == b'\x05\x01\x00'
            connection.sendall(b'\x05\x00')
            assert read_exact(connection, 4) == b'\x05\x01\x00\x01'
            assert socket.inet_ntoa(read_exact(connection, 4)) == '198.51.100.12'
            assert int.from_bytes(read_exact(connection, 2), 'big') == 443
            connection.sendall(b'\x05\x00\x00\x01\x7f\x00\x00\x01\x00\x00')
        assert proc.wait(timeout=10) == 0, 'Proxied TCP connection failed'
    print('PASS: eligible TCP connection used the SOCKS5 proxy')

    # The configured proxy is now closed: loopback must still connect directly.
    with listener() as local:
        proc = subprocess.Popen([str(probe), '127.0.0.1', str(local.getsockname()[1])], env=env)
        with local.accept()[0]:
            pass
        assert proc.wait(timeout=10) == 0, 'Loopback did not remain direct'
    print('PASS: loopback connection bypassed the proxy')

    # Failure to read config must not silently fall back to external direct TCP.
    (temp / 'config.json').unlink()
    proc = subprocess.run([str(probe), '198.51.100.12', '443'], env=env, timeout=10)
    assert proc.returncode != 0, 'Missing config unexpectedly allowed the connection'
    print('PASS: missing configuration rejects the intercepted external connection')
