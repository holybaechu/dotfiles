# Rhythm-game recording

Close OBS before running `chezmoi apply`. In OBS, select **Rhythm Games** from
both **Profile** and **Scene Collection**. Recordings go to your Windows Videos folder.

| Setting | Value |
| --- | --- |
| Canvas and output | 2880×1800, matching the current primary display; 60 fps |
| Video | Intel Quick Sync AV1, ICQ 14, balanced TU4 preset |
| Color | 10-bit P010, SDR Rec. 709, limited range |
| Container | Hybrid MP4 |
| Audio | Game audio only, stereo 48 kHz AAC at 320 kbps |

The profile targets visually lossless recording with hardware encoding. ICQ 14
still uses lossy compression and 4:2:0 color sampling; it does not guarantee exact
pixels or artifact-free output. Hybrid MP4 supports recovery after interruption;
keep the original file until you have checked playback.

Start the game in fullscreen at the display resolution. The **Rhythm Game** source
captures fullscreen games and their audio without the cursor or third-party overlays.
For a windowed game or a black preview, open that source's **Properties**, select
**Capture specific window**, and choose the game. If Game Capture cannot hook the
game, use Window Capture and add Application Audio Capture for the game instead.

Make a short recording of a busy chart and check **View → Stats** for rendering
lag and encoding lag. Leave GPU headroom if either counter rises; lower the game's
graphics load or cap its frame rate while keeping the display at 120 Hz. Check
fast notes, colored edges, and audio sync in playback before a long session.

If the primary display changes, update both canvas and output dimensions in
**Settings → Video**, and fit the source to the canvas. This profile requires
Intel Quick Sync AV1 support and an AV1-capable player or editor. Reapplying
dotfiles restores the managed profile and scene, including source selection.

References: [OBS recording settings](https://obsproject.com/kb/advanced-recording-settings-guide),
[Game Capture](https://obsproject.com/kb/game-capture-source),
[Hybrid MP4](https://obsproject.com/kb/hybrid-mp4).
