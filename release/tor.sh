#!/usr/bin/env bash
# release/tor.sh -- all release gates before a commit, with honest exit status.
# `python3 release/sperr-scan.py . | tail -1 && git commit` swallows the gate status
# (the pipeline delivers tail's exit code): on 05/06.10 commits with hard findings slipped through.
# Therefore: every gate runs individually, exit != 0 on the first error.
#   release/tor.sh            # sperr-scan (leak/blob scan) + doku-index --pruefen
#   release/tor.sh --tests    # also runs installer/tests/run.sh (~470 tests) and h713-power tests
set -uo pipefail
cd "$(dirname "$0")/.."
rc=0
python3 release/sperr-scan.py . > /tmp/tor-sperr.$$ 2>&1 || { rc=1; grep -E "FINDING|FUND|hard|harte" /tmp/tor-sperr.$$; }
tail -1 /tmp/tor-sperr.$$; rm -f /tmp/tor-sperr.$$
python3 release/doku-index.py --pruefen || rc=1
if [[ "${1:-}" == "--tests" ]]; then bash installer/tests/run.sh > /tmp/tor-tests.$$ 2>&1 || { rc=1; tail -5 /tmp/tor-tests.$$; }; grep -E "^Ran|^OK|^FAILED" /tmp/tor-tests.$$; rm -f /tmp/tor-tests.$$
  # h713-power decides between standby and poweroff: its tests belong in the gate (~2 s)
  python3 -m unittest discover -s userspace/h713-power/tests > /tmp/tor-tests.$$ 2>&1 || { rc=1; tail -5 /tmp/tor-tests.$$; }; grep -E "^Ran|^OK|^FAILED" /tmp/tor-tests.$$ | sed 's/^/h713-power: /'; rm -f /tmp/tor-tests.$$
  # h713-keys maps remote keys (volume, mute, focus): ~1 s
  python3 -m unittest discover -s userspace/h713-keys/tests > /tmp/tor-tests.$$ 2>&1 || { rc=1; tail -5 /tmp/tor-tests.$$; }; grep -E "^Ran|^OK|^FAILED" /tmp/tor-tests.$$ | sed 's/^/h713-keys: /'; rm -f /tmp/tor-tests.$$
  # h713-lamp sets lamp levels: ~1 s
  python3 -m unittest discover -s userspace/h713-lamp/tests > /tmp/tor-tests.$$ 2>&1 || { rc=1; tail -5 /tmp/tor-tests.$$; }; grep -E "^Ran|^OK|^FAILED" /tmp/tor-tests.$$ | sed 's/^/h713-lamp: /'; rm -f /tmp/tor-tests.$$; fi
[[ $rc -eq 0 ]] && echo "Gates: ALL GREEN (Tore: alle gruen)" || echo "Gates: RED -- DO NOT COMMIT (Tore: ROT)"
exit $rc
