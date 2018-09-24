# Debian CIS Benchmark

## 1 - Patching and Software Updates
### 1.1 - Install Updates, Patches and Additional Security Software
**Audit:**
```
# sudo apt update
# sudo apt --just-print upgrade
```
**Remediation:**
```
# sudo apt upgrade
```
## 2 - Filesystem Configuration
### 2.1 - Create Separate Partition for /tmp
**Audit:**
```
# sudo mount | grep /tmp
```
**Remediation:**
```
# sudo systemctl enable tmp.mount
```
Ensure proper settings for the `/tmp` mount are set in `/etc/systemd/system/tmp.mount`.
