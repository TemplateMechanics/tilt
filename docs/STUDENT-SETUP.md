# Before the session

Read this a few days early, not the night before. If something is going to go
wrong, it will go wrong during the download, and the download is the one part
nobody can speed up in the room.

## 1. Install the tools

The versions and links are in the [Prerequisites table](../README.md#prerequisites).
Two of them catch people out:

- **bash.** The scripts here are bash. On Windows that means **Git Bash**,
  which comes with Git for Windows. PowerShell and cmd.exe cannot run them.
- **kubectl.** It must be within one minor version of the cluster. An older
  one prints a version-skew warning on *every* command, and you will spend the
  session reading that warning instead of the output underneath it.

  Check which one you are actually running, not just that one is installed:

  ```bash
  kubectl version -o json | grep gitVersion     # client vs server
  ```

  Docker Desktop installs its own kubectl and puts it on your PATH. On the
  machine this was written on it was v1.34.1 against a v1.36.1 cluster, and
  it shadowed everything else. Installing a current kubectl somewhere earlier
  on PATH fixes it; leave Docker Desktop's copy alone, because Docker Desktop
  replaces it on update anyway.

## 2. Bring the platform up at home

```bash
git clone <this repo>
cd tilt
./scripts/platform.sh up
```

The first run downloads several gigabytes of container images. Measured on a
destroyed-and-rebuilt cluster on a fast laptop with a fast connection,
<https://hello.localhost> answered **8.5 minutes** after Tilt started. Allow
appreciably longer on a slower connection: almost all of that time is
downloading, so your wifi sets the number, not your CPU. It is done when Tilt
shows `hello-world` green and the page loads.

Do this **at home, on wifi you trust**. Twenty laptops pulling the same images
through one conference connection is the single most reliable way to lose the
first hour of a class. The images land inside the kind cluster, not in your
local image cache, so this download happens again for anyone who destroys their
cluster.

Leave the cluster in place when you are done. You do not need Tilt running
until the session starts.

## 3. Prove it works

```bash
./scripts/student-check.sh
```

It checks the tools, the container daemon, disk space, version skew and
whether the platform actually answers a request. It changes nothing.

Anything red is worth an email to your instructor **before** the day. "It
finished with no errors" and "it works" are different claims, and this script
is the difference between them — which is also the subject of half the labs.

## 4. On the day

```bash
./scripts/platform.sh up      # starts Tilt against the cluster you already built
```

Then open <http://localhost:10350> for Tilt and start at
[`labs/`](../labs/README.md).

## If it breaks

Breaking it is the point, and it is disposable:

```bash
./scripts/platform.sh reset   # destroys the cluster and gives you an empty one
./scripts/platform.sh up      # rebuild
```

Do not run that during the session without asking — it re-downloads everything.
Each lab has a cheaper way back in its own README, under **Leaving the lab** or
**Fix**.

## What you need

- A laptop with about 15 GB free and 8 GB of RAM to spare.
- Admin rights to install a container runtime.
- No access to any cloud account. Everything runs locally.
