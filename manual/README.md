### **Setup for the Scripts**
This guide explains how to configure **GitHub Secrets** and **SSH Access** for deploying Frappe applications using **GitHub Actions**.

---

## **1. Required GitHub Secrets**
You need to set the following secrets in your GitHub repository:

| Secret Name         | Description |
|---------------------|-------------|
| `GITHUB_TOKEN`      | Used for authenticating with the GitHub API to fetch branches. (Automatically available in GitHub Actions) |
| `SERVER_IP`         | The public IP address of your VPS/server hosting the Frappe application. |
| `SSH_USER`          | The username used to SSH into the server (e.g., `frappe` or `root`). |
| `SSH_KEY`           | The private SSH key used for authentication (see SSH setup below). |
| `DEFAULT_SITE`      | The default Frappe site (e.g., `hfhg.redsofterp.com`). |

---

## **2. Setting Up SSH Access for GitHub Actions**
GitHub Actions needs **SSH access** to your VPS to execute the deployment.

### **Step 1: Generate an SSH Key (If Not Already Done)**
Run this command on your **local machine** (or inside your server if you don’t have an SSH key):
```bash
ssh-keygen -t rsa -b 4096 -C "your-email@example.com"
```
- **Press Enter** to accept the default location (`~/.ssh/id_rsa`).
- Set a **passphrase (optional, but recommended for security).**
- This will generate:
  - **Private Key**: `~/.ssh/id_rsa`
  - **Public Key**: `~/.ssh/id_rsa.pub`

---

### **Step 2: Copy the Public Key to the Server**
Run this command to add the public key to your VPS:
```bash
ssh-copy-id -i ~/.ssh/id_rsa.pub user@your-server-ip
```
If `ssh-copy-id` is not available, manually copy the public key:
```bash
cat ~/.ssh/id_rsa.pub
```
Copy the output and add it to the **`~/.ssh/authorized_keys`** file on your server.

---

### **Step 3: Add the Private Key to GitHub Secrets**
1. Open your **GitHub repository**.
2. Go to **Settings → Secrets and variables → Actions**.
3. Click **New repository secret**.
4. Add a secret named **`SSH_KEY`**.
5. Copy and paste the contents of your **private key** (`~/.ssh/id_rsa`) into the secret.


### **Secrets to Add**
| Secret Name  | Value Example |
|--------------|--------------|
| `GITHUB_TOKEN` | (Automatically available, no need to set manually) |
| `SERVER_IP`  | `192.168.1.10` (Your VPS IP address) |
| `SSH_USER`   | `frappe` or `ubuntu` |
| `SSH_KEY`    | Paste the contents of `~/.ssh/id_rsa` |
| `DEFAULT_SITE` | `hfhg.redsofterp.com` |



## **3. Running the GitHub Actions Workflow**
Once everything is set up, you can manually trigger the **GitHub Actions workflow**:
1. Go to your **GitHub repository**.
2. Click **Actions**.
3. Select **Deploy Frappe Apps** workflow.
4. Click **Run Workflow** and enter:
   - **App Name**: e.g., `public_app_1`
   - **Branch**: e.g., `main`
   - **Commit ID** (optional)
   - **Site Name** (optional, defaults to `DEFAULT_SITE`)

---

## **5. Verifying Deployment**
- The workflow will **validate the branch, site, and health check** before deploying.
- Check logs in **GitHub Actions** to see deployment progress.
- If successful, your Frappe app should be updated on your server.
