#!/usr/bin/env python3
"""Serve the Flutter web bundle with headers required by Google Sign-In."""

from __future__ import annotations

import argparse
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class OrganoteWebHandler(SimpleHTTPRequestHandler):
    """Static file handler that adds browser auth compatibility headers."""

    def end_headers(self) -> None:
        self.send_header("Cross-Origin-Opener-Policy", "same-origin-allow-popups")
        self.send_header("Referrer-Policy", "strict-origin-when-cross-origin")
        super().end_headers()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Serve a built Flutter web app with Google Sign-In headers.",
    )
    parser.add_argument(
        "--directory",
        "-d",
        default="build/web",
        help="Directory to serve. Defaults to build/web.",
    )
    parser.add_argument(
        "--bind",
        "-b",
        default="0.0.0.0",
        help="Address to bind. Defaults to 0.0.0.0.",
    )
    parser.add_argument(
        "--port",
        "-p",
        type=int,
        default=8080,
        help="Port to bind. Defaults to 8080.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    directory = Path(args.directory).resolve()
    handler = lambda *handler_args, **handler_kwargs: OrganoteWebHandler(
        *handler_args,
        directory=str(directory),
        **handler_kwargs,
    )
    server = ThreadingHTTPServer((args.bind, args.port), handler)
    print(
        "Serving {directory} at http://{host}:{port}/ with COOP "
        "same-origin-allow-popups".format(
            directory=directory,
            host=args.bind,
            port=args.port,
        ),
        flush=True,
    )
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
