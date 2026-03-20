# vid-hub

# Video Worker

This node owns everything video-related:

- RTP parsing
- frame assembly
- live stream
- HLS/video writing
- replay and playback
- recordings and video-side storage

## Port

- `API_PORT=3200`

## One-shot droplet setup

On a fresh Ubuntu droplet:

```bash
curl -fsSL https://raw.githubusercontent.com/TakundaMabukwa/vid-hub/main/bootstrap-droplet.sh -o bootstrap-droplet.sh
chmod +x bootstrap-droplet.sh
sudo ./bootstrap-droplet.sh
```

After that, edit:

```bash
sudo nano /opt/vid-hub/.env
```

Set at least:

- `SERVER_IP=<video-public-ip>`
- `INTERNAL_WORKER_TOKEN=<shared-secret>`
- `CORS_ORIGIN=*`

Then restart:

```bash
cd /opt/vid-hub
pm2 restart ecosystem.config.js --update-env
pm2 logs video-video-worker --lines 100
```

Health check:

```bash
curl http://127.0.0.1:3200/health
```
