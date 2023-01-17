#!/usr/bin/env nix-shell
#! nix-shell -p python3Full -i python
import hashlib
import json
import subprocess
import urllib.request

LOCAL_JSON_PATH = "sources.json"
ZIG_JSON_URL = "https://ziglang.org/download/index.json"
PLATFORMS = {"aarch64-linux", "x86_64-linux", "aarch64-macos", "x86_64-macos", "aarch64-windows", "x86_64-windows"}
PUBLIC_KEY = "RWSGOq2NVecA2UPNdBUZykf1CCb147pkmdtYxgb3Ti+JO/wCYvhbAb/U"

def fix_release(release):
    "Fix all the null SHA256 entries in a single release."
    for platform_key in release:
        platform = release[platform_key]
        if platform["sha256"] != None or platform["url"] == None:
            continue
        print(f'fixing version={platform["version"]} platform={platform_key}')

        try:
            sigfile, _ = urllib.request.urlretrieve(platform["url"] + ".minisig")
            binfile, _ = urllib.request.urlretrieve(platform["url"])

            sigcheck = subprocess.run([
                "minisign",
                "-V",
                "-P", PUBLIC_KEY,
                "-x", sigfile,
                "-m", binfile,
            ], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

            if sigcheck.returncode != 0:
                print('  failed signature check!')
                continue

            platform["sha256"] = sha256_file(binfile)
        except urllib.error.HTTPError as e:
            # 403 is semantically 404 for Zig
            if e.code == 403:
                platform["broken"] = True
                platform["sha256"] = "BROKEN. THIS IS PURPOSELY INVALID."
            else:
                print(f'  failed download: {e}')
        finally:
            urllib.request.urlcleanup()

def sha256_file(file_name):
    "Compute the SHA256 hash of a file."
    h = hashlib.sha256()
    with open(file_name, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            h.update(chunk)
    return h.hexdigest()

def main():
    """
    This "fixes" our sources.json by finding all releases with a null sha256
    and computing the value. Prior to computing the value, we validate the
    signature, too.

    We should probably merge all of ./update logic into here, but I bolted
    this on at some point because it works. Contributions welcome!
    """
    # Load our local sources
    with open(LOCAL_JSON_PATH, encoding="utf-8") as f:
        local = json.load(f)

    # Go through master releases
    for release_name in local:
        release = local[release_name]

        if release_name == "master":
            for date in release:
                fix_release(release[date])
        else:
            fix_release(release)

    # Save
    with open(LOCAL_JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(local, f, indent=2)

if __name__ == "__main__":
    main()
