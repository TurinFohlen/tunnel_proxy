#!/usr/bin/env python3
"""通过 PTY 隧道在 Termux 上执行命令（无 marker 方式）"""
import socket, time, sys

def exec_cmd(cmd: str, timeout: int = 20) -> str:
    s = socket.socket()
    s.settimeout(timeout)
    s.connect(('frp.freefrp.net', 11096))
    s.sendall(f'{cmd}\n'.encode())
    time.sleep(3)
    data = b''
    try:
        while True:
            d = s.recv(4096)
            if not d: break
            data += d
    except socket.timeout:
        pass
    s.close()
    # 去掉第一行（命令回显）
    lines = data.decode('utf-8', errors='replace').split('\n')
    return '\n'.join(lines[1:]).strip()

if __name__ == '__main__':
    cmd = ' '.join(sys.argv[1:]) if len(sys.argv) > 1 else 'echo usage: texec.py "command"'
    print(f"[→] {cmd}")
    out = exec_cmd(cmd)
    print(out if out else '(无输出)')
