# sticky-session-proxy-tester: how long does a sticky session keep its IP?

To find out how long a sticky session really keeps the same exit IP, check the exit through the session at a fixed interval, opening a new connection every time, and note the moment the address changes. The time from the first check to the last check that still showed the old IP is the least it held; the time to the first check with a new IP is the most. `sticky-test.sh` does this with curl and prints a timeline plus a summary line for every IP it saw. Run it before you build a multi-step job on sticky sessions, so each job fits inside the time an exit actually lasts for you.

Proxy302 maintains this tool and sells these proxies: rotating residential traffic from $1.50/GB, where you pick a sticky session with the session parameter your provider documents; Proxy302's console generates it for you ([prices](https://proxy302.com/pricing/)). The script works with any provider's sticky login.

## Usage

```bash
git clone https://github.com/proxy302/sticky-session-proxy-tester
cd sticky-session-proxy-tester
./sticky-test.sh 'http://SESSION_LOGIN:PASS@HOST:PORT'            # every 30 s for up to 30 min
./sticky-test.sh 'http://SESSION_LOGIN:PASS@HOST:PORT' 10 60      # every 10 s for up to 60 min
./sticky-test.sh 'socks5h://SESSION_LOGIN:PASS@HOST:PORT' 15 20
```

`SESSION_LOGIN` stands for the username that carries the session parameter, copied from your console. Ctrl-C ends the test early and still prints the summary. Needs bash and curl. `CHECK_URL` changes the echo service (default `https://api.ipify.org`).

## Example output

This run used a local stand-in whose exit changes every 20 seconds, checked every 4 seconds, so the change detection is easy to follow. Addresses masked:

```
Checking every 4s for up to 1 min, a new connection each time. Ctrl-C ends early.
time       elapsed  exit
04:42:59      0:00  A  x.x.x.x
04:43:03      0:04  B  x.x.x.x   <- changed from A after 0:00 to 0:04
04:43:07      0:08  B  x.x.x.x
04:43:11      0:12  B  x.x.x.x
04:43:15      0:16  B  x.x.x.x
04:43:19      0:20  B  x.x.x.x
04:43:23      0:24  C  x.x.x.x   <- changed from B after 0:16 to 0:20
...
04:43:59      1:00  D  x.x.x.x

== Summary: 16 checks, 0 failed
  A  x.x.x.x  held at least 0:00, changed before 0:04
  B  x.x.x.x  held at least 0:16, changed before 0:20
  C  x.x.x.x  held at least 0:16, changed before 0:20
  D  x.x.x.x  held at least 0:16, still the exit when the test ended
3 change(s). Real hold times lie between the two numbers on each line;
a shorter interval narrows the gap.
```

Ignore the first IP's figures when the session was already in use before the test started: the script only knows when it first saw it.

## How to read the result

| Output | Meaning |
|---|---|
| `held at least X, changed before Y` | The exit lasted somewhere between X and Y |
| `still the exit when the test ended` | It had not changed yet; run longer to find the end |
| `The exit IP never changed during the test` | The session outlasted the test. A static IP should always look like this |
| `check failed` lines | The proxy did not answer that check. A failure right before a change often marks the moment the old exit went away |
| A letter that comes back later (A, B, A) | The session returned to an earlier exit. Treat each change as a new IP all the same |

## Using the numbers

- **Size your jobs to the low end.** If exits held between 9 and 10 minutes in your runs, design a job that finishes well inside that.
- **Restart, don't resume.** When the exit changes mid-job, start that job again from the beginning instead of carrying on halfway with a new address.
- **Give each worker its own session.** Two workers on one session leave from one IP.
- **Run the test more than once,** at the time of day you will actually work. One run is one sample.
- **Keep checks on new connections.** That is what the script does: an open, reused connection would keep its exit and hide the change.

## FAQ

**My provider states a session time, but the IP changed sooner. Why?** A sticky exit can end before its window does. Build the job so it can restart, as above.

**Can I test a static IP with it?** Yes. A static IP should show one letter for the whole test; anything else means the connection is not going where you think.

**How much traffic does it use?** Each check is one TLS handshake and a body of under 20 bytes, so a 30-minute run at 30-second intervals is small even on a per-GB plan.

**Is a sticky session right for an account I log in to every day?** No. Sticky sessions suit minutes of work. An account used over days or weeks belongs on a static residential (ISP) IP; see [rotating vs sticky sessions](https://proxy302.github.io/proxy-guides/rotating-vs-sticky-sessions/).

*Facts checked 19 November 2026.*
