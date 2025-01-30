# 🚀 Frappe Docker Deployment with Custom Apps Guide

This guide helps you deploy **Frappe applications using Docker**, ensuring a stable and scalable setup.

---

## **1️⃣ Prerequisites**
Before starting, ensure you have:
[refer to frappe docker single server setup for prerequisites install](https://github.com/frappe/frappe_docker/blob/main/docs/single-server-example.md)
- **Docker & Docker Compose** installed.
- **Git** installed.
- **Personal Access Token (PAT) for GitHub** (if using private repositories).
- A properly configured **`.env`** and **`apps.json`** inside the `frappe_docker` directory.

---

### **2️⃣ Clone `frappe_docker` Repository**
All commands should be executed inside the `frappe_docker` directory.

```bash
git clone https://github.com/frappe/frappe_docker.git
cd frappe_docker
```

Create and configure **`.env`** and **`apps.json`** inside this directory.

---

## **3️⃣ Required Environment Variables**
Ensure your `.env` file contains these variables:

```ini
ERPNEXT_VERSION=v15.47.3  [for installing ERPNext]
DB_PASSWORD=your-db-password
UPSTREAM_REAL_IP_ADDRESS=your-server-ip
HTTP_PUBLISH_PORT=80
LETSENCRYPT_EMAIL=your-email@redsofterp.com
SITES=redsofterp.com
HOST_IP=your-host-ip

[if want to add trafik dashboard]
USERNAME=admin
HASHED_PASSWORD=your-hashed-password
TRAEFIK_DOMAIN=localhost
```

---

## **4️⃣ Configure `apps.json`**
This file lists the custom apps that should be included.

- **Edit `apps.json`**:
  ```bash
  nano apps.json
  ```

- **Example Format**:
  ```json
  [
    {
      "url": "https://{{PAT}}@github.com/yourusername/yourapp.git",
      "branch": "main"
    }
  ]
  ```

- **Replace `{{PAT}}` with your actual token**:
  ```bash
  export PAT=your_github_pat
  sed -i "s|{{PAT}}|$PAT|g" apps.json
  ```

- **Encode `apps.json` to Base64**:
  ```bash
  export APPS_JSON_BASE64=$(base64 -w 0 apps.json)
  ```

---

## **5️⃣ Build Docker Image**
By default, the build process uses a **pre-built image** with default versions of Node.js and Python. you can change frappe branch to specific version.
You can choose to build from scratch: [Refer to the official guide](https://github.com/frappe/frappe_docker/blob/main/docs/custom-apps.md).

- **Build the image**:
  ```bash
  docker build \
    --build-arg FRAPPE_PATH=https://github.com/frappe/frappe \
    --build-arg FRAPPE_BRANCH=version-15 \
    --build-arg APPS_JSON_BASE64=$APPS_JSON_BASE64 \
    --tag ghcr.io/yourusername/frappe-yourapp/prod:1.0.0 \
    --file images/layered/Containerfile .
  ```

---

## **6️⃣ (Optional) Push Image to GitHub Registry**
👉 **Skip this step if building directly on the server**. Instead, set `PULL_POLICY=never` in the next step to use local image.

- **Authenticate and push the image**:
  ```bash
  echo $CR_PAT | docker login ghcr.io -u your_github_username --password-stdin
  docker push ghcr.io/yourusername/frappe-yourapp/prod:1.0.0
  ```

---

## **7️⃣ Set Environment Variables**
Define variables for deployment:

```bash
export CUSTOM_IMAGE='ghcr.io/yourusername/frappe-yourapp/prod'
export CUSTOM_TAG='1.0.0'
export PULL_POLICY='never'  # Set to 'always' if pulling from a registry
```

---

## **8️⃣ Generate `docker-compose.yaml`**
The following command will generate the **`docker-compose.yaml`** file.

```bash
docker compose -f compose.yaml \
  -f overrides/compose.mariadb.yaml \
  -f overrides/compose.redis.yaml \
  -f overrides/compose.https.yaml \
  config > ~/gitops/docker-compose.yaml
```

To understand what these **override files** do and check if you need different ones,  
[Read this guide](https://github.com/frappe/frappe_docker/blob/main/docs/list-of-containers.md).

---

## **9️⃣ Deploy Services**
- **Pull images**:
  ```bash
  docker compose --project-name frappe-yourapp -f ~/gitops/docker-compose.yaml pull
  ```
- **Stop running services**:
  ```bash
  docker compose --project-name frappe-yourapp -f ~/gitops/docker-compose.yaml down
  ```
- **Start services**:
  ```bash
  docker compose --project-name frappe-yourapp -f ~/gitops/docker-compose.yaml up -d
  ```

---

## **🔟 (First-Time Setup) Create Site & Install Apps**
If this is a fresh deployment, you must **create the site and install apps**.

1. **Create a new site**:
   ```bash
   docker exec -it frappe-yourapp-backend-1 bench new-site hfhg.redsofterp.com --admin-password=yourpassword
   ```

2. **Install necessary apps**:
   ```bash
   docker exec -it frappe-yourapp-backend-1 bench --site hfhg.redsofterp.com install-app erpnext
   docker exec -it frappe-yourapp-backend-1 bench --site hfhg.redsofterp.com install-app your-custom-app
   ```
3. Restore Backup: [If applicable]
  ```bash
  bench --site yoursite.com --force restore /path/to/backup.sql.gz --with-private-files /path/to/private-files.tar --with-public-files /path/to/public-files.tar
  ```
  
---

## **1️⃣1️⃣ Verify Deployment**
- **Check running containers**:
  ```bash
  docker ps
  ```
- **Run migrations**:
  ```bash
  docker exec -it frappe-yourapp-backend-1 bench --site hfhg.redsofterp.com migrate
  ```


### **✅ Automate Deployment using `deploy_changes.sh`**
Use the script below to automate the redeployment process.

### **💡 How to Use the Script**
1. Make it executable:
   ```bash
   chmod +x deploy_changes.sh
   ```
2. Deploy:
   ```bash
   ./deploy_changes.sh 1.0.1
   ```
