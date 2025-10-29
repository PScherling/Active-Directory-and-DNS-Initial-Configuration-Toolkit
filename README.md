# Active Directory / DNS Server Initial Configuration

## Overview
This repository contains a **fully automated PowerShell-based setup framework** for deploying and configuring a complete **Active Directory Domain Controller** with integrated **DNS Server** and post-deployment automation scripts.  
Designed for reliability, repeatability, and logging, this toolkit enables system administrators to bootstrap an entire Windows Server AD environment from zero, including OU structure, GPOs, users, and groups.

> 💡 This toolkit can be used as a standalone automation suite or as an **add-on for the [PSC-SConfig Menu](https://github.com/PScherling/psc_sconfig)** for seamless system administration.

---

## 🧩 PSC_SConfig Integration
For enhanced usability, integrate this repository with **[PSC-SConfig](https://github.com/PScherling/psc_sconfig)**.  
This allows direct menu-based access to all ADDS configuration and management scripts.

<img width="1024" height="768" alt="image" src="https://github.com/user-attachments/assets/96fcf5a5-a85f-4c19-b796-a14c7d898d47" />
<img width="1024" height="768" alt="image" src="https://github.com/user-attachments/assets/f2a83d79-e1ad-4e7c-9837-65fbe00ead8b" />

---

## Key Features
- Automated Active Directory and DNS configuration
- Domain setup and post-installation routines
- Automated creation of Organizational Units (OU) and GPO linking
- Bulk import/export of AD users and groups
- Automated OU-to-GPO linking and policy deployment
- Extendable modular script design
- Centralized logging with detailed status output
- Supports multi-DC environments (including Add-DC automation)

---

## System Requirements

| Requirement | Minimum |
|--------------|----------|
| **OS** | Windows Server 2019 / 2022 / 2025 |
| **PowerShell** | Version 5.1 or later |
| **Privileges** | Must be executed as Administrator |
| **Network** | Static IP configuration recommended |
| **Modules** | ActiveDirectory, DnsServer |

---

## Network Configuration
- Static-IP Adress
- DNS: 127.0.0.1, [Static-IP-Adress]

---

## Folder & Script Structure

### 0_DNS_AD_Initial_Setup
| Script | Description |
|---------|--------------|
| **1_ad-dns-server-configuration_final.ps1** | Installs and configures DNS Server roles and forwarders. |
| **2_ad-setup_final.ps1** | Promotes the server to a new domain controller and creates the `domain.at` forest. |
| **3_ad-post-setup-tasks_final.ps1** | Performs domain post-setup configurations such as DNS verification and replication settings. |
| **4_ad-setup_add-dc_final.ps1** | Adds an additional Domain Controller to an existing domain. |

<img width="1024" height="769" alt="image" src="https://github.com/user-attachments/assets/f622d872-aece-4dac-8ffb-1e9a8adbc9f5" />
<img width="1024" height="769" alt="image" src="https://github.com/user-attachments/assets/96a40047-fb11-4f05-b5ce-95779e464345" />
<img width="1024" height="769" alt="image" src="https://github.com/user-attachments/assets/83278fe4-c34d-4a2e-ac76-200ea49321ba" />


---

### 1_GroupPolicies
| Script | Description |
|---------|--------------|
| **1_AddAndImport_GPOSet.ps1** | Imports pre-defined GPO backups and links them to their respective OUs. |
| **2_CreateCentralPolicyStore.ps1** | Creates a central policy store in `SYSVOL` for unified GPO management. |

<img width="1024" height="769" alt="image" src="https://github.com/user-attachments/assets/47f0cd97-7fc0-46bf-a429-79917c451e0e" />
<img width="1024" height="769" alt="image" src="https://github.com/user-attachments/assets/fca223a0-6268-4570-98cd-40480ed152a9" />


---

### 2_OU-Template_Import
| Script | Description |
|---------|--------------|
| **1_ad-ou-std-creation_final.ps1** | Creates a standardized OU hierarchy under `CompanyRoot` to maintain a clean and structured AD layout. |

<img width="1023" height="770" alt="image" src="https://github.com/user-attachments/assets/087522be-26ef-49f2-b42d-a0b626242667" />


---

### 3_AD_Groups_Import
| Script | Description |
|---------|--------------|
| **1_group-import_final.ps1** | Bulk-imports Active Directory groups from a predefined CSV file. |

<img width="1023" height="770" alt="image" src="https://github.com/user-attachments/assets/aa96c1a6-fd1c-472b-a1a7-d20b0c428a1a" />


---

### 4_AD_User_Import
| Script | Description |
|---------|--------------|
| **1_user-import_final.ps1** | Bulk-imports users into Active Directory with properties such as department, email, and group membership. |

<img width="1023" height="770" alt="image" src="https://github.com/user-attachments/assets/7b2579d8-2a83-497c-8374-3c2a11c63707" />
<img width="1024" height="82" alt="image" src="https://github.com/user-attachments/assets/976cf211-1361-4258-b5b4-eec48b6050da" />


---

### 5_AD_AddUserToGroup
| Script | Description |
|---------|--------------|
| **1_ad-adduserstogroups_final.ps1** | Automates adding users to security or distribution groups based on input mappings. |

<img width="1023" height="770" alt="image" src="https://github.com/user-attachments/assets/daa0e2a6-e60d-4168-b6dd-22b5e0a7a9d9" />


---

### 6_AD_OU-GPO-Link_Import
| Script | Description |
|---------|--------------|
| **1_ou-gpo-link-import_final.ps1** | Links existing Group Policies to Organizational Units using CSV mapping for consistent deployment. |

<img width="1024" height="769" alt="image" src="https://github.com/user-attachments/assets/bda85a8b-89b7-4300-b1be-5449dd21cfd7" />


---

### 7_AD_User-Export-Import
| Script | Description |
|---------|--------------|
| **AD-bulk-user-export.ps1** | Exports existing AD users to CSV for backup or replication. |
| **AD-bulk-user-import.ps1** | Re-imports users from CSV into the domain, preserving key attributes. |

---

## Execution Order

1 **DNS and Domain Setup**
```powershell
. 1_ad-dns-server-configuration_final.ps1
. 2_ad-setup_final.ps1
. 3_ad-post-setup-tasks_final.ps1
```

2 **OU and GPO Configuration**
```powershell
. 1_AddAndImport_GPOSet.ps1
. 2_CreateCentralPolicyStore.ps1
. 1_ad-ou-std-creation_final.ps1
```

3 **Group and User Import**
```powershell
. 1_group-import_final.ps1
. 1_user-import_final.ps1
. 1_ad-adduserstogroups_final.ps1
```

4 **Linking and Export**
```powershell
. 1_ou-gpo-link-import_final.ps1
. 1_AD-bulk-user-export.ps1
. 1_AD-bulk-user-import.ps1
```

---

## Logging

All scripts include a built-in logging mechanism that records:
- Execution time and hostname
- Script actions and PowerShell output
- Error details and exception traces  

Default log directory:
```
C:\_it\Logs\
```
or on remote log share:
```
\\<MDT-Server>\Logs$\Custom\
```

---

## Notes & Best Practices
- Always execute PowerShell with **Administrator privileges**
- Verify **network and DNS connectivity** before promotion
- Customize CSVs before importing groups or users
- The scripts are **idempotent** where possible (safe to re-run)
- Ensure **secure storage** of credential and product key data
- Use a **staging environment** before running in production

---

## 👤 Author

**Author:** Patrick Scherling  
**Contact:** @Patrick Scherling  

---

> ⚡ *“Automate. Standardize. Simplify.”*  
> Part of Patrick Scherling’s IT automation suite for modern Windows Server infrastructure management.
