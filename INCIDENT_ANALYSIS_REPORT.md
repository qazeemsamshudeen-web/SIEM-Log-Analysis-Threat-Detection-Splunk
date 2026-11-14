# 🚨 SOC Incident Analysis Report: SSH Brute-Force Attack (T1110.001)

### Technical Deliverable: Log Analysis, Attack Attribution, and Host Hardening
**Document Classification:** Internal SOC Forensic Report  
**Author / Lead Security Analyst:** Qazeem Samsudeen Temitope ([@qazeemsamshudeen-web](https://github.com/qazeemsamshudeen-web) | *BlaqqSec*)  
**Target Environment:** Ubuntu Server 22.04 LTS (`10.0.0.5`)  
**SIEM Platform:** Splunk Enterprise v9.2.2  
**Incident Reference:** INC-2026-1112-SSH01  

---

## 1. Executive Summary

On November 12, 2026, the Security Operations Center (SOC) detected an anomalous surge in remote authentication failures targeting the primary Ubuntu application server (`10.0.0.5`) on port 22 (OpenSSH). Real-time telemetry ingested into **Splunk Enterprise** triggered high-severity threshold alerts, confirming an automated, multi-threaded password guessing attack (credential stuffing).

Forensic log correlation attributed **100% of the unauthorized attempts** to source IP **`10.0.0.3`** (Kali Linux security testing host). The threat actor utilized **THC-Hydra v9.7** attempting to brute-force privileged access to the `root` administrative account. 

No system compromise or privilege escalation occurred. Immediate containment was achieved via network-level and host-level defensive measures, followed by permanent host-hardening implementations (Fail2ban IPS and OpenSSH password authentication revocation).

---

## 2. Threat Classification & MITRE ATT&CK Alignment

| Metric | Technical Value / Mapping |
| :--- | :--- |
| **MITRE ATT&CK Tactic** | TA0006: Credential Access |
| **MITRE ATT&CK Technique** | **T1110.001: Brute Force — Password Guessing** |
| **Target Service** | OpenSSH Server 8.9p1 (TCP Port 22) |
| **Target Identity** | `root` (UID 0 / Administrator) |
| **Attacker Source IP** | `10.0.0.3` (Internal Subnet Host) |
| **Attack Tooling** | THC-Hydra v9.7 (Multi-threaded dictionary generator) |
| **Attack Volume** | 20 Failed Authentication Events across 2 distinct attack bursts |
| **Incident Severity** | **High (P2)** — Active Targeted Credential Attack |

---

## 3. Incident Timeline & Forensic Reconstruction

```text
+-----------------------------------------------------------------------------------+
|                            INCIDENT FORENSIC TIMELINE                             |
+-----------------------------------------------------------------------------------+
 [17:10:00 UTC] Baseline SOC Monitoring: Splunk ingestion active for /var/log/auth.log
 [17:12:15 UTC] Initial Burst Detected: 10 Rapid SSH failed logins for user 'root' from 10.0.0.3
 [17:12:45 UTC] Attack Pause: Automated thread delay / socket reset from THC-Hydra client
 [17:13:30 UTC] Secondary Burst Detected: 10 Additional failed attempts with alternate dictionary
 [17:14:00 UTC] Velocity Spike Alert: Splunk Single-Value KPI exceeded threshold (>5 failures)
 [17:15:30 UTC] SOC Analyst Triage: Attacker IP 10.0.0.3 attributed via Rex parsing SPL
 [17:18:00 UTC] Incident Containment: Host IPS (Fail2ban) enabled; SSH password auth disabled
```

---

## 4. Telemetry Analysis & Splunk Forensic Queries

### 4.1 Ingested Raw Telemetry (`/var/log/auth.log`)
The Splunk Universal forwarder/monitor captured raw syslog events with sourcetype `linux_secure`:
```text
Nov 12 17:12:15 mylabserver sshd[3142]: Failed password for root from 10.0.0.3 port 45210 ssh2
Nov 12 17:12:16 mylabserver sshd[3144]: Failed password for root from 10.0.0.3 port 45212 ssh2
Nov 12 17:12:16 mylabserver sshd[3146]: Failed password for root from 10.0.0.3 port 45214 ssh2
```

### 4.2 Forensic SPL Queries Executed

#### A. Total Failed Authentication Volume
```spl
index=* sourcetype=linux_secure "Failed password" 
| stats count as "Total Attack Volume"
```
*Result:* **20 events confirmed** triggering the Red Alert threshold on the SOC dashboard.

#### B. Attacker Source Attribution & Frequency Sorting
```spl
index=* sourcetype=linux_secure "Failed password" 
| rex "from (?<attacker_ip>\d+\.\d+\.\d+\.\d+)" 
| stats count as "Failed Attempts" by attacker_ip 
| sort - "Failed Attempts"
```
*Result Table:*
| attacker_ip | Failed Attempts | Risk Score |
| :--- | :--- | :--- |
| `10.0.0.3` | 20 | High (100% Volume Attribution) |

#### C. Attack Velocity & Spike Charting
```spl
index=* sourcetype=linux_secure "Failed password" 
| timechart span=1m count
```
*Analysis:* The column chart revealed two isolated, narrow towers of 10 requests/minute, characteristic of scripted dictionary attacks rather than human error.

---

## 5. Correlated Perimeter Telemetry (Multi-Vector Defense)

Simultaneously, the target server was inspected for secondary attack vectors. Splunk ingested Apache ModSecurity WAF telemetry (`/var/log/apache2/error.log`):
```spl
index=* source=*apache* "Access denied with code 403"
```
*Forensic Finding:* Splunk confirmed 8 critical web attack block events triggered by ModSecurity Rule `941160` (Cross-Site Scripting XSS probe from `10.0.0.3`), proving the threat actor was conducting concurrent multi-vector reconnaissance.

---

## 6. Root Cause & Vulnerability Assessment

1. **Permissive Authentication Policy:** SSH password authentication was initially enabled on the target server, allowing remote clients to submit unlimited credential guesses without progressive delays or lockouts.
2. **Direct Root Login Exposure:** The OpenSSH configuration allowed direct administrative logins (`PermitRootLogin yes`), presenting a high-value static target for automated wordlists.
3. **Absence of Host-Level Rate Limiting:** Out of the box, Ubuntu lacked an active Intrusion Prevention System (IPS) to detect and ban attacking IP addresses after repeated failures.

---

## 7. Remediation & Host Hardening Implemented

### Phase 1: Automated Intrusion Prevention (Fail2ban)
Deployed and configured `fail2ban` to monitor `/var/log/auth.log` and dynamically inject `iptables` drop rules:
```bash
sudo apt-get install -y fail2ban
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
```
*Jail Configuration (`/etc/fail2ban/jail.local`):*
```ini
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600
findtime = 600
```
*Verification:* An attacker exceeding 5 failures is now dropped at the kernel firewall level for 1 hour.

### Phase 2: Complete OpenSSH Protocol Hardening
Enforced non-password, cryptographic key-based authentication:
```bash
# 1. Prohibit direct root access
sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

# 2. Disable password authentication entirely
sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# 3. Restart SSH daemon
sudo systemctl restart ssh
```
*Outcome:* Password guessing attacks via THC-Hydra are rendered completely ineffective, returning `Permission denied (publickey)`.

---

## 8. Lessons Learned & SOC Recommendations

1. **Continuous Centralized SIEM Monitoring:** Ingesting both endpoint authentication logs and perimeter WAF telemetry into a centralized SIEM (Splunk) is vital for correlating multi-stage kill chains.
2. **Alert Thresholds:** Establish automated SIEM alert actions (Webhook/Email notifications) whenever authentication failure velocity exceeds 5 attempts per minute.
3. **Zero-Trust Access Model:** Restrict SSH access to trusted management IP addresses via firewall rules (`ufw allow from <ADMIN_IP> to any port 22`) and mandate Multi-Factor Authentication (MFA) for production environments.
