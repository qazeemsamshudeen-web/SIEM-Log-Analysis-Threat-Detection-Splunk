# 📘 Day 4 Operational Runbook: SIEM Threat Detection & Incident Response
### Comprehensive Step-by-Step Reproduction Guide: Splunk SIEM Deployment, SSH Brute-Force Telemetry & AI Risk Assessment

* **Author / Lead Analyst:** Qazeem Samsudeen Temitope (*BlaqqSec*)
* **Specialization:** Security Operations Center (SOC) & Application Security
* **Target Server:** Ubuntu Server 22.04 LTS (`10.0.0.5`)
* **Attacker Machine:** Kali Linux VM (`10.0.0.3`)
* **SIEM Solution:** Splunk Enterprise v9.2.2 (Linux 64-bit .deb)

---

## 🔗 Official Splunk Enterprise Download Links

* **Direct Package Download (Linux 64-bit .deb):**  
  `https://download.splunk.com/products/splunk/releases/9.2.2/linux/splunk-9.2.2-d76edf6f0a15-linux-2.6-amd64.deb`
* **Official Splunk Portal:**  
  `https://www.splunk.com/en_us/download/splunk-enterprise.html`
* **Download Command (Ubuntu Terminal):**
  ```bash
  wget -O splunk.deb "https://download.splunk.com/products/splunk/releases/9.2.2/linux/splunk-9.2.2-d76edf6f0a15-linux-2.6-amd64.deb"
  ```

---

## 🛠️ Step-by-Step Reproduction Guide

### Phase 1: Host Storage Optimization & LVM Expansion
During deployment, the Ubuntu root filesystem (`/`) was 97% full (only 415 MB free) due to default LVM installer partitioning.
1. Inspect Volume Group for unallocated space:
   ```bash
   sudo lsblk
   sudo vgs
   ```
2. Extend the logical volume to claim 100% of free disk space (+11.5 GB):
   ```bash
   sudo lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
   sudo resize2fs /dev/ubuntu-vg/ubuntu-lv
   ```
3. Verify storage expansion (Available space increases to **12+ GB**):
   ```bash
   df -h /
   ```

---

### Phase 2: Splunk SIEM Deployment & Service Initialization
1. Download Splunk Enterprise package:
   ```bash
   wget -O splunk.deb "https://download.splunk.com/products/splunk/releases/9.2.2/linux/splunk-9.2.2-d76edf6f0a15-linux-2.6-amd64.deb"
   ```
2. Install package via `dpkg`:
   ```bash
   sudo dpkg -i splunk.deb
   ```
3. Start Splunk and accept the license agreement:
   ```bash
   sudo /opt/splunk/bin/splunk start --accept-license
   ```
   * Set administrator username: `admin`
   * Set administrator password: `[YourPassword]`
4. Enable automatic startup on boot:
   ```bash
   sudo /opt/splunk/bin/splunk enable boot-start
   ```
5. Allow Splunk Web GUI port in Ubuntu firewall:
   ```bash
   sudo ufw allow 8000/tcp
   ```
6. Access Splunk Web interface from Kali browser:
   ```text
   http://10.0.0.5:8000
   ```

---

### Phase 3: Telemetry Pipeline & Log Ingestion Configuration
1. Grant read permissions on target log files:
   ```bash
   sudo chmod 644 /var/log/auth.log
   sudo chmod 644 /var/log/apache2/*.log
   ```
2. Ingest Linux Authentication Telemetry (CLI or Web UI):
   ```bash
   sudo /opt/splunk/bin/splunk add monitor /var/log/auth.log -sourcetype linux_secure -auth admin:[YourPassword]
   ```
3. Ingest Web Application & WAF Telemetry (CLI or Web UI):
   ```bash
   sudo /opt/splunk/bin/splunk add monitor /var/log/apache2/error.log -sourcetype apache_error -auth admin:[YourPassword]
   ```

---

### Phase 4: Attack Simulation Execution (THC-Hydra from Kali Linux)
From Kali Linux (`10.0.0.3`):
1. Create credential wordlists:
   ```bash
   cat << 'EOF' > /tmp/users.txt
   root
   admin
   ubuntu
   guest
   test
   EOF

   cat << 'EOF' > /tmp/passwords.txt
   123456
   password
   admin123
   letmein
   qwerty
   toor
   dragon
   welcome
   ninja
   master
   EOF
   ```
2. Launch multi-threaded SSH credential-stuffing attack:
   ```bash
   hydra -l root -P /tmp/passwords.txt -t 4 -V ssh://10.0.0.5
   ```
   *(Hydra attempts 10 passwords against user `root`, generating real-time authentication failure telemetry).*

---

### Phase 5: SIEM Threat Hunting & Forensic SPL Queries
In Splunk Web (`Search & Reporting`), execute:
1. **Detect All Authentication Failures:**
   ```spl
   index=* sourcetype=linux_secure "Failed password"
   ```
2. **Attacker Source IP Attribution Table:**
   ```spl
   index=* sourcetype=linux_secure "Failed password" 
   | rex "from (?<attacker_ip>\d+\.\d+\.\d+\.\d+)" 
   | stats count as "Failed Attempts" by attacker_ip 
   | sort - "Failed Attempts"
   ```
3. **Attack Spike Frequency Over Time:**
   ```spl
   index=* sourcetype=linux_secure "Failed password" 
   | timechart span=1m count
   ```
4. **Correlated Web WAF Telemetry:**
   ```spl
   index=* source=*apache* "Access denied with code 403"
   ```

---

### Phase 6: SOC Threat Monitoring Dashboard Deployment (Deliverable 1)
1. In Splunk, go to **Dashboards** > **Create New Dashboard** (Select **Classic Dashboards**).
2. Title: `SOC Threat Monitoring - SSH Brute-Force Incident (T1110)`.
3. Click **Edit** > **Source**, replace contents with the following XML, and click **Save**:

```xml
<dashboard version="1.1" theme="dark">
  <label>SOC Threat Monitoring - SSH Brute-Force Incident (T1110)</label>
  <description>Real-time detection and forensic attribution of credential-stuffing attack on Ubuntu Server</description>
  <fieldset submitButton="false">
    <input type="time" token="time_picker" searchWhenChanged="true">
      <label>Time Window</label>
      <default>
        <earliest>-24h@h</earliest>
        <latest>now</latest>
      </default>
    </input>
  </fieldset>
  <row>
    <panel>
      <title>Total Authentication Failures (Attack Volume)</title>
      <single>
        <search>
          <query>index=* sourcetype=linux_secure "Failed password" | stats count</query>
          <earliest>$time_picker.earliest$</earliest>
          <latest>$time_picker.latest$</latest>
        </search>
        <option name="colorMode">block</option>
        <option name="rangeColors">["0x53a051","0xdc4e41"]</option>
        <option name="rangeValues">[5]</option>
        <option name="useColors">1</option>
      </single>
    </panel>
    <panel>
      <title>Attacker Source IP Attribution</title>
      <table>
        <search>
          <query>index=* sourcetype=linux_secure "Failed password" | rex "from (?&lt;attacker_ip&gt;\d+\.\d+\.\d+\.\d+)" | stats count as "Failed Attempts" by attacker_ip | sort - "Failed Attempts"</query>
          <earliest>$time_picker.earliest$</earliest>
          <latest>$time_picker.latest$</latest>
        </search>
        <option name="count">10</option>
        <option name="drilldown">none</option>
      </table>
    </panel>
  </row>
  <row>
    <panel>
      <title>Authentication Failure Rate Spike (Attempts/min)</title>
      <chart>
        <search>
          <query>index=* sourcetype=linux_secure "Failed password" | timechart span=1m count</query>
          <earliest>$time_picker.earliest$</earliest>
          <latest>$time_picker.latest$</latest>
        </search>
        <option name="charting.chart">column</option>
        <option name="charting.chart.showDataLabels">all</option>
        <option name="charting.legend.placement">none</option>
      </chart>
    </panel>
  </row>
</dashboard>
```

---

### Phase 7: Host Hardening & Incident Remediation
1. **Automated Host IPS (Fail2ban):**
   ```bash
   sudo apt-get install -y fail2ban
   sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
   # Enable [sshd] jail with maxretry = 5, bantime = 3600
   sudo systemctl restart fail2ban
   ```
2. **Disable Root SSH Login & Password Auth:**
   ```bash
   sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
   sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
   sudo systemctl restart ssh
   ```

---

### Phase 8: Adversarial ML Tool Evaluation Reference (Deliverable 3)
* **Tool:** Microsoft Counterfit (Automated Adversarial AI Security Assessment).
* **Framework Mapping:** MITRE ATLAS (`AML.T0015` Evasion, `AML.T0018` Data Poisoning, `AML.T0040` Model Inversion).
* **Governance Standard:** NIST AI Risk Management Framework (AI RMF 1.0 - Govern, Map, Measure, Manage).
