# Frappe Backup Automation with Restic

This script automates the backup process for Frappe sites, storing encrypted backups securely in an S3-compatible storage using Restic. It ensures database and site files are backed up efficiently and securely.

## Prerequisites

### 1. Install Restic
Restic is a fast and secure backup solution. Install it with:
```
sudo apt install restic -y
```

### 2. Set Up AWS IAM Permissions
The backup script uses an **S3-compatible storage** for storing encrypted backups. To allow access, create an **IAM user** in AWS and attach the following policy:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:GetBucketLocation"
            ],
            "Resource": "arn:aws:s3:::your-s3-bucket-name"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject",
                "s3:PutObjectAcl",
                "s3:GetObjectAcl"
            ],
            "Resource": "arn:aws:s3:::your-s3-bucket-name/*"
        }
    ]
}
```

- Replace `your-s3-bucket-name` with the **actual bucket name** you created in AWS S3.
- Ensure the IAM user has **programmatic access**.

### 3. Create an S3 Bucket
- Go to **AWS Console → S3**.
- Create a bucket, e.g., **your-s3-bucket-name**.
- Ensure you note the **region** where the bucket is created.

## Configuration

### 1. Set Up Environment Variables
Create a `.env` file in `/home/user/ci_cd/` and add the following **exported** variables:

```
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export RESTIC_PASSWORD="your-strong-password"
export RESTIC_REPOSITORY="s3:s3.amazonaws.com/your-s3-bucket-name"
```

- Ensure this file is sourced before running the script:
  ```
  source /home/user/ci_cd/.env
  ```

---

### 2. Setting Up `default_site.txt`
If you don't want to specify a site every time, **create a `default_site.txt` file** inside `/home/user/ci_cd/`:

```
your-default-site-name.com
```

- If **no site is passed as an argument**, the script will read the site from `default_site.txt`.

## Understanding the `backup.sh` Script

This script performs the following:

1. **Loads environment variables** from `.env`.
2. **Checks if Restic is installed** (`restic version`).
3. **Verifies if the Restic repository exists** (`restic snapshots`).
4. **Initializes the Restic repository** if it does not exist (`restic init`).
5. **Runs Frappe's built-in backup** (`bench --site site-name backup --with-files`).
6. **Uploads the backup to S3 using Restic** (`restic backup`).
7. **Applies backup retention policy** (`restic forget`).
8. **Verifies the integrity of backups** (`restic check`).
9. **Logs the backup process**.

### Retention Policy (`restic forget`)
The script includes a **backup retention policy** to automatically delete older backups while keeping recent ones.

```sh
restic forget \
    --keep-last 10 \      # Always keep the last 10 backups
    --keep-daily 30 \     # Keep daily backups for the last 30 days
    --keep-weekly 26 \    # Keep weekly backups for 6 months
    --keep-within 15d \   # Keep all backups from the last 15 days
    --keep-monthly 12 \   # Keep one monthly backup for the last 12 months
    --prune \             # Remove unnecessary backup data
    --tag "backup-tag"
```

This ensures:
- **Recent backups are available** for the last 15 days.
- **Daily backups for the last 30 days**.
- **Weekly backups for the last 6 months**.
- **Monthly backups for up to 1 year**.
- **Automatic cleanup of old backups** to save space.

## Running the Backup Manually

To trigger a backup manually, run:

```
/home/user/ci_cd/backup.sh your-site-name
```

If no site name is provided, it will use the **default site** from `default_site.txt`.


## Automating Backups with Cron

To ensure backups run automatically, **set up a cron job**.

1. Open crontab:
   ```
   crontab -e
   ```

2. Add this line to run the backup every **6 hours**:
   ```
   0 */6 * * * /bin/bash /home/user/ci_cd/backup.sh >> /home/user/ci_cd/logs/backup_cron.log 2>&1
   ```

This will:
- Run the backup **every 6 hours**.
- Log the output to `/home/user/ci_cd/logs/backup_cron.log`.

---

## Logging
Backup logs are stored in:
```
/home/user/ci_cd/logs/
```
To check the latest log:
```
tail -f /home/user/ci_cd/logs/backup_cron.log
```

## Troubleshooting

### 1. Verify Restic Installation
```
restic version
```

### 2. Check If Backups Exist
```
restic -r s3:s3.amazonaws.com/your-s3-bucket-name snapshots
```

### 3. Validate AWS Credentials
```
aws s3 ls s3://your-s3-bucket-name/
```

### 4. Manually Initialize Restic Repository
If you see an error **"repository does not exist"**, initialize it manually:
```
restic -r s3:s3.amazonaws.com/your-s3-bucket-name init
```

## Security Considerations

- **Never store credentials in scripts** – always use the `.env` file.
- **Ensure backups are encrypted** – Restic encrypts all data before storing.
- **Use IAM permissions** to limit S3 access to only necessary actions.


## License
This project is licensed under the MIT License.
