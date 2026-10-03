"""Bridge newline-delimited JSON-RPC on stdio to a Codex app-server control socket.

The control socket only accepts WebSocket connections and carries one JSON-RPC
message per text frame, while Desktop's app-server child speaks JSON lines.
`codex app-server proxy` copies bytes without translating, so the server drops
the connection at the handshake and Desktop waits on `initialize` forever.
"""

import asyncio
import sys

from websockets.asyncio.client import unix_connect
from websockets.exceptions import ConnectionClosed, WebSocketException


async def stdin_to_socket(ws):
    loop = asyncio.get_running_loop()
    # Prompts with large attachments arrive as a single line.
    reader = asyncio.StreamReader(limit=1 << 30)
    await loop.connect_read_pipe(
        lambda: asyncio.StreamReaderProtocol(reader), sys.stdin.buffer
    )
    while line := await reader.readline():
        line = line.rstrip(b"\r\n")
        if line:
            await ws.send(line.decode())
    await ws.close()


async def socket_to_stdout(ws):
    out = sys.stdout.buffer
    # The server hangs up without a close frame, so an abrupt close is the
    # normal end of a session.
    try:
        async for message in ws:
            if isinstance(message, str):
                message = message.encode()
            out.write(message + b"\n")
            out.flush()
    except ConnectionClosed:
        pass


async def main(socket_path):
    async with unix_connect(
        socket_path,
        uri="ws://localhost/",
        max_size=None,
        compression=None,
    ) as ws:
        tasks = [
            asyncio.create_task(stdin_to_socket(ws)),
            asyncio.create_task(socket_to_stdout(ws)),
        ]
        # Either side closing ends the session; Desktop treats the child
        # exiting as a lost connection rather than a hung one.
        done, pending = await asyncio.wait(
            tasks, return_when=asyncio.FIRST_COMPLETED
        )
        for task in pending:
            task.cancel()
        for task in done:
            task.result()


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(f"usage: {sys.argv[0]} SOCKET")
    try:
        asyncio.run(main(sys.argv[1]))
    except (OSError, WebSocketException) as err:
        sys.exit(f"codex-app-server-ws-proxy: {sys.argv[1]}: {err}")
