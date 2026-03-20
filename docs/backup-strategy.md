# Backup Strategy

## What to Back Up

| Data Type             | Location                          | Priority | Method              |
|-----------------------|-----------------------------------|----------|---------------------|
| Compose files         | This Git repo                     | Critical | Git push (automatic)|
| `.env` files          | Per-service `.env`                | Critical | Encrypted backup    |
| Database volumes      | Named Docker volumes              | High     | Volume snapshot     |
| Media files (Immich)  | `${NAS_PATH}/appdata/immich/upload` | High   | rsync / Restic      |
| Config directories    | `${NAS_PATH}/appdata/*/`          | High     | rsync / Restic      |
| Model cache           | `${NAS_PATH}/hf_*_models/`        | Low      | Re-download if lost |
| Compiled caches       | `${NAS_PATH}/*-cache/`            | None     | Always regenerate   |

## Backup Script

The included `scripts/backup.sh` creates `.tar.gz` archives of named Docker volumes.

```bash
# Backup all services
./scripts/backup.sh

# Backup one service
./scripts/backup.sh media/immich

# Custom output directory
BACKUP_DIR=/mnt/nas/backups ./scripts/backup.sh
```

## Recommended: Restic + Backblaze B2

For offsite backup (~$1–2/month), use [Restic](https://restic.net) with Backblaze B2:

```bash
# Install restic
apt install restic

# Initialize repo (one-time)
restic -r b2:your-bucket-name:homelab init

# Backup appdata
restic -r b2:your-bucket-name:homelab backup /mnt/nas/appdata

# Schedule daily (add to crontab)
# 0 2 * * * restic -r b2:your-bucket-name:homelab backup /mnt/nas/appdata
```

## Before Upgrading a Service

For stateful services (Immich, Tandoor, Homebox, Nextcloud), always back up before updating:

```bash
# 1. Backup volumes
./scripts/backup.sh media/immich

# 2. Pull new images
make pull SERVICE=media/immich

# 3. Update
make up SERVICE=media/immich

# 4. Verify data integrity
```

## Restore Procedure

```bash
# Stop the service
make down SERVICE=media/immich

# Restore volume from backup
docker run --rm \
  -v immich_postgres_data:/target \
  -v /path/to/backup:/backup:ro \
  alpine tar xzf /backup/media-immich-20260101-020000.tar.gz -C /target --strip-components=2

# Start the service
make up SERVICE=media/immich
```

## Disaster Recovery Checklist

1. Install Docker and NVIDIA drivers on new host
2. Clone this repo: `git clone https://github.com/davidamacey/OpenHomeLab`
3. Create shared network: `make network`
4. Restore `.env` files from encrypted backup
5. Restore data volumes from Restic/B2 backup
6. Start services: `make up-all`
7. Verify each service at its port
