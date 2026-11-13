# ucm

The ALSA UCM profiles of the phones' sound cards, laid out as
`/usr/share/alsa/ucm2`, in one package beside Arch's `alsa-ucm-conf`:
`alsa-ucm-phonewave` (`image/recipes/alsa-ucm-phonewave`). ALSA picks a
profile by the card's driver and name, so every phone gets them all and uses
its own.

| Card | Phone |
|---|---|
| `sm8550/astonsnd` | OnePlus Ace 3 |
| `kaanapali/Nubia-NX809J` | RedMagic 11 Pro |
| `kaanapali/OnePlus-Pad4` | OnePlus Pad 4 |
| `kaanapali/Xiaomi-17` | Xiaomi 17 |
| `sm7325/Xiaomi-Lisa` | Xiaomi 11 Lite 5G NE |

WirePlumber sets the phones' cards to software volume
(`image/rootfs/usr/share/wireplumber/wireplumber.conf.d/51-phone-audio.conf`).

Lisa's `HiFi` verb establishes the MultiMedia1 playback and MultiMedia2 capture
backend routes before ACP probes the PCMs: recent DPCM kernels reject an open
without a backend. Independent frontends are required because Q6ASM cannot
prepare playback and capture in the same session. Install this UCM only with a
kernel/DT exposing `MultiMedia2` at PCM device 1. The
speaker device then unmutes the container-protected TFA9873 path, and disabling
it mutes without removing the verb's probe route. `52-xiaomi-lisa.conf` beside
the common WirePlumber rule fixes speaker playback at S16LE, 48 kHz, stereo
`FL,FR`; do not use the pro-audio profile's default eight-channel format.

Keep `/usr/lib/firmware/tfa98xx.cnt` and the calibrated 6160/7575 mOhm values.
After deployment, select `HiFi`, set the real speaker sink as default, and
persist a low software volume before reconnecting streams. Playback acceptance
must use a short, fade-enveloped signal no greater than 2% PCM full scale,
never full-scale `speaker-test`.
